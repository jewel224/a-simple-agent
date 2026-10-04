import json
import time
import uuid
from typing import Any

from qwen_agent.agents import Assistant

from app.governance.audit import AuditService
from app.governance.config import get_settings
from app.governance.db import get_database_manager
from app.governance.errors import AgentExecutionError
from app.governance.masking import mask_sensitive_rows
from app.governance.memory import MemoryService
from app.governance.semantic import SemanticService
from app.governance.sql_guard import scoped_sql_validation
from app.governance.tool import GovernedSQLTool, get_last_tool_result, reset_last_tool_result


class GovernedAgentService:
    """把语义检索、qwen-agent、记忆和审计串联成一次受治理请求。"""

    def __init__(self):
        self.settings = get_settings()
        self.db_manager = get_database_manager()
        self.memory = MemoryService(self.db_manager)
        self.semantic = SemanticService(self.db_manager)
        self.audit = AuditService(self.db_manager)
        self.tool = GovernedSQLTool()

    def _extract_text(self, messages: list[Any]) -> str:
        def extract_message(value: Any) -> str | None:
            # qwen-agent 在工具调用异常等场景可能把消息包在嵌套 list 中。
            if isinstance(value, list):
                for child in reversed(value):
                    text = extract_message(child)
                    if text:
                        return text
                return None
            if not isinstance(value, dict):
                return None

            content = value.get("content")
            if value.get("role") != "assistant" or not content:
                return None
            if isinstance(content, str):
                return content
            if isinstance(content, list):
                parts = []
                for item in content:
                    if isinstance(item, dict) and "text" in item:
                        parts.append(str(item["text"]))
                return "\n".join(parts) if parts else None
            return None

        for message in reversed(messages):
            text = extract_message(message)
            if text:
                return text
        raise AgentExecutionError("Agent 未返回自然语言答案")

    @staticmethod
    def _is_safety_rejection(question: str, answer: str) -> bool:
        """识别针对受限字段的明确安全拒绝，避免正常问题误入安全路径。"""
        restricted_question = (
            ("收件人" in question and ("姓名" in question or "手机号" in question))
            or ("详细地址" in question and ("订单" in question or "收货" in question))
        )
        rejection_keywords = (
            "无法提供", "无法访问", "拒绝访问", "敏感信息", "敏感字段",
        )
        return restricted_question and any(keyword in answer for keyword in rejection_keywords)

    def _build_safety_rejection_response(
        self,
        *,
        question: str,
        answer: str,
        session_id: uuid.UUID,
        trace_id: uuid.UUID,
        actor_id: str,
        client_ip: str | None,
        request_payload: dict[str, Any],
        semantic_context: dict[str, Any],
        usage: dict[str, Any] | None,
        started_at: float,
    ) -> dict[str, Any]:
        """构造不包含 SQL 和查询结果的安全拒绝响应。"""
        total_duration_ms = int((time.monotonic() - started_at) * 1000)
        response_payload = {
            "answer": answer,
            "sql": None,
            "columns": [],
            "row_count": 0,
            "truncated": False,
            "sql_latency_ms": None,
            "masked_columns": [],
            "safety_rejected": True,
        }
        self.memory.append_message(
            session_id,
            "assistant",
            answer,
            model_name=self.settings.qwen_model,
            token_usage=usage,
        )
        self.audit.log(
            trace_id=trace_id,
            session_id=session_id,
            action="text_to_sql_query",
            actor_id=actor_id,
            request_payload=request_payload,
            response_payload=response_payload,
            result_status="SUCCESS",
            duration_ms=total_duration_ms,
            client_ip=client_ip,
            extra={
                "token_usage": usage,
                "model_name": self.settings.qwen_model,
                "safety_rejected": True,
            },
        )
        return {
            "trace_id": trace_id,
            "session_id": session_id,
            "answer": answer,
            "sql": None,
            "columns": [],
            "rows": [],
            "row_count": 0,
            "truncated": False,
            "safety_rejected": True,
            "used_metadata": {
                "tables": [row["table_name"] for row in semantic_context["tables"]],
                "metrics": [row["metric_code"] for row in semantic_context["metrics"]],
                "examples": [str(row["example_id"]) for row in semantic_context["examples"]],
            },
            "sql_latency_ms": None,
            "latency_ms": total_duration_ms,
            "token_usage": usage,
        }

    def _extract_usage(self, messages: list[Any]) -> dict[str, Any] | None:
        def walk(value: Any) -> dict[str, Any] | None:
            if isinstance(value, dict):
                usage = value.get("usage") or value.get("token_usage")
                if isinstance(usage, dict) and ("input_tokens" in usage or "output_tokens" in usage):
                    return usage
                for child in value.values():
                    found = walk(child)
                    if found:
                        return found
            elif isinstance(value, list):
                for child in value:
                    found = walk(child)
                    if found:
                        return found
            return None

        return walk(messages)

    def query(
        self,
        question: str,
        session_id: uuid.UUID | None,
        actor_id: str,
        client_ip: str | None,
    ) -> dict[str, Any]:
        trace_id = uuid.uuid4()
        session_id = self.memory.ensure_session(session_id, question)
        self.memory.append_message(session_id, "user", question)
        prompt, semantic_context = self.semantic.prepare(question)
        history = self.memory.recent_messages(session_id)
        if not history or history[-1].get("content") != question:
            history.append({"role": "user", "content": question})

        request_payload = {
            "question": question,
            "session_id": str(session_id),
            "trace_id": str(trace_id),
        }
        started_at = time.monotonic()
        reset_last_tool_result()
        try:
            bot = Assistant(
                llm={
                    "model": self.settings.qwen_model,
                    "timeout": 30,
                    "retry_count": 3,
                },
                name="governed_order_agent",
                description="订单业务只读查询与分析",
                system_message=prompt,
                function_list=["governed_sql"],
            )
            semantic_tables = {
                row["table_name"].lower()
                for row in semantic_context["tables"]
            }
            for example in semantic_context["examples"]:
                semantic_tables.update(
                    table_name.lower() for table_name in example["tables_used"]
                )
            semantic_columns = {
                (row["table_name"].lower(), row["column_name"].lower())
                for row in semantic_context["columns"]
            }
            with scoped_sql_validation(semantic_tables, semantic_columns):
                responses = list(bot.run(history))
            answer = self._extract_text(responses)
            tool_result = get_last_tool_result()
            if tool_result is None and self._is_safety_rejection(question, answer):
                usage = self._extract_usage(responses)
                return self._build_safety_rejection_response(
                    question=question,
                    answer=answer,
                    session_id=session_id,
                    trace_id=trace_id,
                    actor_id=actor_id,
                    client_ip=client_ip,
                    request_payload=request_payload,
                    semantic_context=semantic_context,
                    usage=usage,
                    started_at=started_at,
                )
            if tool_result is None:
                raise AgentExecutionError("Agent 未执行 governed_sql 工具")

            masked_rows = mask_sensitive_rows(tool_result.columns, tool_result.rows)
            usage = self._extract_usage(responses)
            total_duration_ms = int((time.monotonic() - started_at) * 1000)
            response_payload = {
                "answer": answer,
                "sql": tool_result.sql,
                "columns": tool_result.columns,
                "row_count": tool_result.row_count,
                "truncated": tool_result.truncated,
                "sql_latency_ms": tool_result.duration_ms,
                "masked_columns": [column for column in tool_result.columns if column.lower() in {"recipient_name_masked", "recipient_phone_masked", "shipping_detail_address_masked"}],
            }
            self.memory.append_message(
                session_id,
                "assistant",
                answer,
                tool_name="governed_sql",
                tool_args={"sql_input": tool_result.sql},
                model_name=self.settings.qwen_model,
                token_usage=usage,
            )
            self.memory.append_message(
                session_id,
                "tool",
                json.dumps({"columns": tool_result.columns, "rows": masked_rows, "row_count": tool_result.row_count}, ensure_ascii=False),
                tool_name="governed_sql",
            )
            self.audit.log(
                trace_id=trace_id,
                session_id=session_id,
                action="text_to_sql_query",
                actor_id=actor_id,
                request_payload=request_payload,
                response_payload=response_payload,
                result_status="SUCCESS",
                duration_ms=total_duration_ms,
                client_ip=client_ip,
                extra={
                    "sql_latency_ms": tool_result.duration_ms,
                    "token_usage": usage,
                    "model_name": self.settings.qwen_model,
                    "row_count": tool_result.row_count,
                    "truncated": tool_result.truncated,
                    "masked_columns": response_payload.get("masked_columns", []),
                },
            )
            return {
                "trace_id": trace_id,
                "session_id": session_id,
                "answer": answer,
                "sql": tool_result.sql,
                "columns": tool_result.columns,
                "rows": masked_rows,
                "row_count": tool_result.row_count,
                "truncated": tool_result.truncated,
                "used_metadata": {
                    "tables": [row["table_name"] for row in semantic_context["tables"]],
                    "metrics": [row["metric_code"] for row in semantic_context["metrics"]],
                    "examples": [str(row["example_id"]) for row in semantic_context["examples"]],
                },
                "sql_latency_ms": tool_result.duration_ms,
                "latency_ms": total_duration_ms,
                "token_usage": usage,
            }
        except Exception as exc:
            duration_ms = int((time.monotonic() - started_at) * 1000)
            error_code = getattr(exc, "code", type(exc).__name__)
            error_message = str(exc)
            self.audit.log(
                trace_id=trace_id,
                session_id=session_id,
                action="text_to_sql_query",
                actor_id=actor_id,
                request_payload=request_payload,
                response_payload={"error": error_message},
                result_status="FAILED",
                duration_ms=duration_ms,
                client_ip=client_ip,
                error_code=error_code,
                error_message=error_message,
            )
            raise




