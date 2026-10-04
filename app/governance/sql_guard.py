import contextvars
import re
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any, Iterator

import sqlglot
from sqlglot import exp

from app.governance.errors import SQLValidationError


ALLOWED_TABLES = {
    "dim_date",
    "dim_region",
    "dim_channel",
    "dim_user",
    "dim_category",
    "dim_merchant",
    "dim_product",
    "dim_promotion",
    "dim_payment_method",
    "fact_order",
    "fact_order_item",
    "fact_payment",
    "fact_refund",
    "fact_app_event",
    "fact_logistics_order",
    "fact_logistics_trace",
    "v_fact_order_item_masked",
}

RESTRICTED_COLUMNS = {
    "recipient_name",
    "recipient_phone",
    "shipping_detail_address",
}

# 结构性关联键不承载敏感业务信息，允许语义字段裁剪后继续用于表关联。
STRUCTURAL_COLUMNS = {
    "category_key", "channel_key", "date_key", "logistics_order_key",
    "merchant_key", "order_item_key", "order_key", "payment_key",
    "payment_method_key", "product_key", "promotion_key", "region_key",
    "user_key",
}

# 维度表业务展示字段和时间字段用于分组、筛选与结果解释；只有对应表进入
# 本次请求语义范围时才允许访问，不放开事实表字段。
DIMENSION_BUSINESS_COLUMNS = {
    "dim_category": {"category_name"},
    "dim_channel": {"channel_name", "channel_type", "platform", "device_platform"},
    "dim_date": {
        "calendar_date", "year", "quarter", "month", "day", "day_name_cn",
        "day_of_week", "week_of_year", "is_weekend", "is_holiday",
    },
    "dim_merchant": {"merchant_name", "merchant_type", "merchant_level"},
    "dim_payment_method": {"method_name", "provider"},
    "dim_product": {"product_name", "brand", "spec"},
    "dim_promotion": {"promotion_name", "promotion_type"},
    "dim_region": {"region_name", "region_path", "region_type"},
}


@dataclass(frozen=True)
class SQLValidationScope:
    """单次请求允许访问的语义表和字段。"""

    tables: frozenset[str]
    columns: frozenset[tuple[str, str]]


_sql_validation_scope: contextvars.ContextVar[SQLValidationScope | None] = contextvars.ContextVar(
    "governed_sql_validation_scope", default=None
)

SAFE_FUNCTIONS = {
    "abs", "avg", "cast", "ceil", "coalesce", "concat", "count", "current_date", "current_timestamp",
    "date_part", "date_trunc", "dense_rank", "extract", "first_value", "floor", "greatest",
    "lag", "last_value", "least", "left", "length", "lower", "lpad", "ltrim", "max", "min",
    "mode", "now", "nullif", "percentile_cont", "percentile_disc", "power", "rank",
    "regexp_replace", "replace", "right", "round", "row_number", "rpad", "rtrim",
    "split_part", "string_agg", "substring", "sum", "to_char", "to_date", "to_timestamp", "time_to_str", "time_to_date", "str_to_time",
    "trim", "upper", "generate_series",
}

FORBIDDEN_KEYWORDS = {
    "copy", "do", "execute", "grant", "revoke", "vacuum", "analyze", "listen", "notify",
}


def _function_name(node: exp.Expression) -> str:
    if isinstance(node.this, str):
        return node.this.lower()
    try:
        return node.sql_name().lower()
    except Exception:
        name = getattr(node, "name", "")
        return name.lower() if isinstance(name, str) else ""


@contextmanager
def scoped_sql_validation(tables: set[str] | frozenset[str], columns: set[tuple[str, str]] | frozenset[tuple[str, str]]) -> Iterator[None]:
    """在当前 Agent 请求内启用语义层命中的表和字段白名单。"""
    normalized_tables = frozenset(name.lower() for name in tables)
    normalized_columns = frozenset(
        (table.lower(), column.lower()) for table, column in columns
    )
    unknown_tables = normalized_tables - ALLOWED_TABLES
    if unknown_tables:
        raise ValueError(f"语义层返回了未授权表: {', '.join(sorted(unknown_tables))}")
    token = _sql_validation_scope.set(
        SQLValidationScope(normalized_tables, normalized_columns)
    )
    try:
        yield
    finally:
        _sql_validation_scope.reset(token)


def _table_aliases(expression: exp.Expression) -> dict[str, str]:
    """把 SQL 表别名映射回真实表名。"""
    aliases: dict[str, str] = {}
    for table in expression.find_all(exp.Table):
        aliases[table.alias_or_name.lower()] = table.name.lower()
    return aliases


def _is_scope_column_allowed(table_name: str, column_name: str, scope: SQLValidationScope) -> bool:
    """判断字段是否来自语义命中、结构性关联键或已命中维度的业务字段。"""
    return (
        (table_name, column_name) in scope.columns
        or column_name in DIMENSION_BUSINESS_COLUMNS.get(table_name, set())
    )


def _is_select_star(node: exp.Expression) -> bool:
    """判断 SELECT * 或 alias.*，不把 COUNT(*) 误判为通配查询。"""
    if isinstance(node.parent, exp.Select):
        return True
    return isinstance(node.parent, exp.Column)

def validate_sql(sql: str) -> str:
    """校验并返回规范化 SQL；任何不满足只读规则的语句都直接拒绝。"""
    if not sql or not sql.strip():
        raise SQLValidationError("SQL 不能为空")

    normalized = sql.strip().rstrip(";")
    try:
        statements = sqlglot.parse(normalized, read="postgres")
    except Exception as exc:
        raise SQLValidationError(f"SQL 解析失败: {exc}") from exc

    if len(statements) != 1 or statements[0] is None:
        raise SQLValidationError("只允许单条 SELECT 或 WITH 查询")

    expression = statements[0]
    if not isinstance(expression, exp.Select):
        raise SQLValidationError("只允许 SELECT 或 WITH 查询")

    forbidden_types = (
        exp.Insert, exp.Update, exp.Delete, exp.Drop, exp.Alter, exp.TruncateTable,
        exp.Grant, exp.Revoke, exp.Command, exp.Create,
    )
    scope = _sql_validation_scope.get()
    cte_names = {
        cte.alias_or_name.lower() for cte in expression.find_all(exp.CTE)
    }
    aliases = _table_aliases(expression)
    # CTE 外层别名必须优先于内层物理表别名，避免 r.year_month 被误解析。
    for table in expression.find_all(exp.Table):
        if table.name.lower() in cte_names:
            aliases[table.alias_or_name.lower()] = table.name.lower()
    cte_output_columns = {
        projection.output_name.lower()
        for cte in expression.find_all(exp.CTE)
        if isinstance(cte.this, exp.Select)
        for projection in cte.this.expressions
        if projection.output_name
    }
    select_output_columns = {
        projection.output_name.lower()
        for select in expression.find_all(exp.Select)
        for projection in select.expressions
        if projection.output_name
    }
    query_output_columns = cte_output_columns | select_output_columns

    allowed_tables = scope.tables if scope is not None else ALLOWED_TABLES
    for table in expression.find_all(exp.Table):
        table_name = table.name.lower()
        if table_name in cte_names:
            continue
        if table_name not in ALLOWED_TABLES:
            raise SQLValidationError(f"禁止访问未授权表: {table_name}")
        if table_name not in allowed_tables:
            raise SQLValidationError(f"当前问题不允许访问表: {table_name}")
        if table.db and table.db.lower() not in {"public", "shop_dw"}:
            raise SQLValidationError(f"禁止访问非 public schema: {table.db}")

    for node in expression.walk():
        if isinstance(node, forbidden_types):
            raise SQLValidationError("禁止执行写入、变更或管理类 SQL")

        if isinstance(node, exp.Column) and node.name.lower() in RESTRICTED_COLUMNS:
            raise SQLValidationError(f"禁止访问敏感字段: {node.name}")

        if (
            scope is not None
            and isinstance(node, exp.Column)
            and node.name.lower() not in STRUCTURAL_COLUMNS
        ):
            column_name = node.name.lower()
            table_reference = node.table.lower() if node.table else ""
            real_table = aliases.get(table_reference, table_reference)
            if real_table in cte_names:
                continue
            if not table_reference and column_name in query_output_columns:
                continue
            if table_reference and real_table:
                if not _is_scope_column_allowed(real_table, column_name, scope):
                    raise SQLValidationError(
                        f"当前问题不允许访问字段: {real_table}.{column_name}"
                    )
            elif not any(
                _is_scope_column_allowed(table_name, column_name, scope)
                for table_name in scope.tables
            ):
                raise SQLValidationError(f"当前问题不允许访问字段: {column_name}")

        if isinstance(node, (exp.Connector, exp.Not)):
            continue
        if isinstance(node, exp.Func):
            function_name = _function_name(node)
            if function_name and function_name not in SAFE_FUNCTIONS:
                raise SQLValidationError(f"禁止使用非白名单函数: {function_name}")

    keyword_tokens = {token.lower() for token in re.findall(r"[A-Za-z_]+", normalized)}
    if keyword_tokens & FORBIDDEN_KEYWORDS:
        raise SQLValidationError("SQL 包含被禁止的关键字")

    has_fact_order_item = any(
        table.name.lower() == "fact_order_item" for table in expression.find_all(exp.Table)
    )
    has_select_star = any(
        isinstance(node, exp.Star) and _is_select_star(node)
        for node in expression.walk()
    )
    if has_fact_order_item and has_select_star:
        raise SQLValidationError("fact_order_item 不允许 SELECT *，请显式选择非敏感字段")
    if scope is not None and has_select_star:
        raise SQLValidationError("当前语义范围不允许 SELECT *，请显式选择字段")

    try:
        return expression.sql(dialect="postgres")
    except Exception as exc:
        raise SQLValidationError(f"SQL 规范化失败: {exc}") from exc





