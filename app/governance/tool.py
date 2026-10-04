import contextvars
import json
from dataclasses import dataclass, field
from typing import Any

from qwen_agent.tools.base import BaseTool, register_tool

from app.governance.errors import ApiError
from app.governance.masking import mask_sensitive_rows
from app.governance.sql_executor import SQLExecutor
from app.governance.sql_guard import validate_sql


@dataclass
class SQLToolResult:
    sql: str
    columns: list[str] = field(default_factory=list)
    rows: list[list[Any]] = field(default_factory=list)
    row_count: int = 0
    truncated: bool = False
    duration_ms: int = 0


_last_tool_result: contextvars.ContextVar[SQLToolResult | None] = contextvars.ContextVar(
    "governed_sql_last_result", default=None
)


def get_last_tool_result() -> SQLToolResult | None:
    """读取当前请求最近一次受治理 SQL 执行结果。"""
    return _last_tool_result.get()


def reset_last_tool_result() -> None:
    """每次 Agent 请求开始前清空旧工具结果，避免跨请求误用。"""
    _last_tool_result.set(None)


@register_tool("governed_sql")
class GovernedSQLTool(BaseTool):
    """只读 SQL 工具，执行前经过 SQL 白名单校验。"""

    description = "执行经过只读校验的 PostgreSQL SQL，并返回 JSON 格式查询结果"
    parameters = [
        {
            "name": "sql_input",
            "type": "string",
            "description": "要执行的 PostgreSQL SELECT 或 WITH 查询",
            "required": True,
        }
    ]

    def call(self, params: str, **kwargs) -> str:
        args = json.loads(params)
        sql = args.get("sql_input")
        try:
            validate_sql(sql)
            result = SQLExecutor().execute(sql)
        except ApiError as exc:
            # 返回结构化错误给 Agent，促使模型修正 SQL 后重试；
            # 只有成功执行的结果才会写入请求级工具结果。
            return json.dumps(
                {
                    "error": {"code": exc.code, "message": exc.message},
                    "columns": [],
                    "rows": [],
                    "row_count": 0,
                    "truncated": False,
                },
                ensure_ascii=False,
            )
        result["rows"] = mask_sensitive_rows(result["columns"], result["rows"])
        tool_result = SQLToolResult(
            sql=result["sql"],
            columns=result["columns"],
            rows=result["rows"],
            row_count=result["row_count"],
            truncated=result["truncated"],
            duration_ms=result["duration_ms"],
        )
        _last_tool_result.set(tool_result)
        return json.dumps(result, ensure_ascii=False, default=str)
