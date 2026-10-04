from typing import Any

from sqlalchemy import text

from app.governance.config import get_settings
from app.governance.db import DatabaseManager, get_database_manager
from app.governance.embedding import EmbeddingClient
from app.governance.errors import SemanticMetadataError


class SemanticService:
    """从语义层检索表、字段、指标和示例，并组装动态 Prompt。"""

    def __init__(self, db_manager: DatabaseManager | None = None):
        self.settings = get_settings()
        self.db_manager = db_manager or get_database_manager()
        self.embedding_client = EmbeddingClient()

    def _search(self, table: str, vector: str, limit: int) -> list[dict[str, Any]]:
        if table == "table_metadata":
            sql = text(
                """
                SELECT table_name, business_meaning, grain
                FROM governance.table_metadata
                WHERE embedding IS NOT NULL AND is_active = true
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT :limit
                """
            )
        elif table == "column_metadata":
            sql = text(
                """
                SELECT table_name, column_name, data_type, business_meaning, sensitive_level
                FROM governance.column_metadata
                WHERE embedding IS NOT NULL
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT :limit
                """
            )
        elif table == "metric_metadata":
            sql = text(
                """
                SELECT metric_code, metric_name, definition, calculation_sql_template, unit, grain
                FROM governance.metric_metadata
                WHERE embedding IS NOT NULL
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT :limit
                """
            )
        elif table == "query_example":
            sql = text(
                """
                SELECT example_id, question, sql_text, tables_used
                FROM governance.query_example
                WHERE embedding IS NOT NULL
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT :limit
                """
            )
        else:
            raise ValueError(f"未知语义对象: {table}")

        try:
            with self.db_manager.engine("embedding").connect() as conn:
                rows = conn.execute(
                    sql,
                    {"embedding": vector, "limit": limit},
                ).mappings().all()
        except Exception as exc:
            raise SemanticMetadataError(f"语义元数据检索失败: {exc}") from exc
        return [dict(row) for row in rows]

    def metadata_readiness(self) -> dict[str, int]:
        """统计治理语义层各类元数据的缺失向量数量，供健康检查使用。"""
        sql = text(
            """
            SELECT
                (SELECT COUNT(*) FROM governance.table_metadata WHERE embedding IS NULL) AS table_metadata,
                (SELECT COUNT(*) FROM governance.column_metadata WHERE embedding IS NULL) AS column_metadata,
                (SELECT COUNT(*) FROM governance.metric_metadata WHERE embedding IS NULL) AS metric_metadata,
                (SELECT COUNT(*) FROM governance.query_example WHERE embedding IS NULL) AS query_example
            """
        )
        with self.db_manager.engine("embedding").connect() as conn:
            row = conn.execute(sql).mappings().one()
        return dict(row)

    def retrieve(self, question: str) -> dict[str, Any]:
        vector = self.embedding_client.embed(question)
        vector_text = EmbeddingClient.to_pgvector(vector)
        result = {
            "tables": self._search("table_metadata", vector_text, self.settings.semantic_table_limit),
            "columns": self._search("column_metadata", vector_text, self.settings.semantic_column_limit),
            "metrics": self._search("metric_metadata", vector_text, self.settings.semantic_metric_limit),
            "examples": self._search("query_example", vector_text, self.settings.semantic_example_limit),
        }
        if not result["tables"] or not result["columns"]:
            raise SemanticMetadataError("语义层缺少表或字段元数据，请先执行向量同步")
        return result

    def prepare(self, question: str) -> tuple[str, dict[str, Any]]:
        context = self.retrieve(question)
        return self._compose_prompt(context), context

    def build_prompt(self, question: str) -> str:
        return self._compose_prompt(self.retrieve(question))

    def _compose_prompt(self, context: dict[str, Any]) -> str:
        table_lines = "\n".join(
            f"- {row['table_name']}: {row['business_meaning']}（粒度：{row['grain']}）"
            for row in context["tables"]
        )
        column_lines = "\n".join(
            f"- {row['table_name']}.{row['column_name']} {row['data_type']}，{row['business_meaning']}，敏感级别 {row['sensitive_level']}"
            for row in context["columns"]
        )
        metric_lines = "\n".join(
            f"- {row['metric_code']}（{row['metric_name']}）：{row['definition']}；计算模板：{row['calculation_sql_template']}"
            for row in context["metrics"]
        )
        example_lines = "\n".join(
            f"- 问题：{row['question']}\n  SQL：{row['sql_text']}"
            for row in context["examples"]
        )
        return f"""你是订单助手，基于手机购物 App 的 shop_dw 星型数仓回答业务问题。

【业务背景】
- PostgreSQL 数据库：shop_dw
- 数据时间范围：2025-01-01 至 2026-09-10
- 全国 31 个省级行政区，江浙沪订单占比偏高
- 大促场景包括 618、双11、双12、双旦礼遇季
- 一个商家只经营一个大类

【相关表】
{table_lines}

【相关字段】
{column_lines}

【指标口径】
{metric_lines or "- 暂无命中指标，请根据字段语义谨慎推断"}

【参考示例】
{example_lines or "- 暂无命中示例"}

【执行规则】
1. 只能调用 governed_sql 工具执行一条 PostgreSQL SELECT 或 WITH 查询。
2. 只能访问语义层给出的表和字段，不得推测或发明不存在的物理字段。
3. 问题包含明确年份、月份或日期范围时必须把它转换为 WHERE 时间条件；订单时间筛选通过事实表日期代理键关联 dim_date，并使用 year/month/calendar_date，不要用支付时间替代订单时间，也不要省略时间条件。
4. 问题要求按月统计时，必须先聚合到月份再输出，退款率分母使用同期支付金额。
5. 展示商家、品类、渠道、省份等业务名称时使用对应 name 字段或省份快照字段，不要输出代理键或业务编号，也不要改别名。
6. 问题同时要求商家和品类时，必须输出 merchant_name 与 category_name 两列；商家来自 dim_merchant，品类来自 dim_category，通过 fact_order_item 的 merchant_key 与 product_key 关联。
7. 退款月度趋势必须输出 year_month、refund_amount、refund_rate 三列；先按月聚合退款与支付，再用同期支付金额作为退款率分母。
8. 不允许访问收件人姓名、手机号、详细地址等敏感字段。
9. 如果问题需要敏感数据，请直接说明无法提供。
10. 拿到查询结果后，用简体中文解释业务结论、关键数字和可能局限。
"""
