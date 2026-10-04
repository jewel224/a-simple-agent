import time
from decimal import Decimal
from typing import Any

from sqlalchemy import text

from app.governance.config import get_settings
from app.governance.db import DatabaseManager, get_database_manager
from app.governance.errors import SQLExecutionError, SQLTimeoutError, SQLValidationError
from app.governance.sql_guard import validate_sql


def to_json_safe(value: Any) -> Any:
    """把 PostgreSQL 返回值转换为可 JSON 序列化的普通 Python 值。"""
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, Decimal):
        return float(value)
    return str(value)


class SQLExecutor:
    """使用 shop_ro 执行只读 SQL，并强制超时和行数限制。"""

    def __init__(self, db_manager: DatabaseManager | None = None):
        self.settings = get_settings()
        self.db_manager = db_manager or get_database_manager()

    def execute(self, sql: str) -> dict[str, Any]:
        safe_sql = validate_sql(sql)
        started_at = time.monotonic()
        try:
            with self.db_manager.engine("shop_ro").connect() as conn:
                conn.execute(text("SET TRANSACTION READ ONLY"))
                conn.execute(
                    text(f"SET LOCAL statement_timeout = {int(self.settings.governed_sql_timeout_ms)}")
                )
                result = conn.execute(text(safe_sql))
                columns = list(result.keys())
                rows = [list(row) for row in result.fetchmany(self.settings.governed_sql_max_rows + 1)]
        except SQLValidationError:
            raise
        except Exception as exc:
            message = str(exc)
            if "statement timeout" in message.lower() or "canceling statement" in message.lower():
                raise SQLTimeoutError(f"SQL 执行超时: {message}") from exc
            raise SQLExecutionError(f"SQL 执行失败: {message}") from exc

        truncated = len(rows) > self.settings.governed_sql_max_rows
        if truncated:
            rows = rows[: self.settings.governed_sql_max_rows]
        json_rows = [[to_json_safe(value) for value in row] for row in rows]
        duration_ms = int((time.monotonic() - started_at) * 1000)
        return {
            "sql": safe_sql,
            "columns": columns,
            "rows": json_rows,
            "row_count": len(json_rows),
            "truncated": truncated,
            "duration_ms": duration_ms,
        }
