import json
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import text

from app.governance.db import DatabaseManager, get_database_manager


class AuditService:
    """将每次受治理请求写入 append-only 操作日志。"""

    def __init__(self, db_manager: DatabaseManager | None = None):
        self.db_manager = db_manager or get_database_manager()

    def log(
        self,
        trace_id: uuid.UUID,
        session_id: uuid.UUID,
        action: str,
        actor_id: str,
        request_payload: dict[str, Any],
        response_payload: dict[str, Any],
        result_status: str,
        duration_ms: int,
        client_ip: str | None,
        error_code: str | None = None,
        error_message: str | None = None,
        extra: dict[str, Any] | None = None,
    ) -> None:
        occurred_at = datetime.utcnow().isoformat()
        with self.db_manager.engine("op_log").begin() as conn:
            conn.execute(
                text(
                    """
                    INSERT INTO audit.operation_log (
                        source_system, service_name, action, actor_id, trace_id, session_id,
                        object_type, object_id, request_payload, response_payload,
                        result_status, error_code, error_message, duration_ms,
                        client_ip, extra
                    ) VALUES (
                        'a-simple-agent', 'governed-order-agent', :action, :actor_id, :trace_id,
                        :session_id, 'agent_request', :object_id, CAST(:request_payload AS jsonb),
                        CAST(:response_payload AS jsonb), :result_status, :error_code,
                        :error_message, :duration_ms, :client_ip, CAST(:extra AS jsonb)
                    )
                    """
                ),
                {
                    "action": action,
                    "actor_id": actor_id,
                    "trace_id": str(trace_id),
                    "session_id": str(session_id),
                    "object_id": str(trace_id),
                    "request_payload": json.dumps(request_payload, ensure_ascii=False, default=str),
                    "response_payload": json.dumps(response_payload, ensure_ascii=False, default=str),
                    "result_status": result_status,
                    "error_code": error_code,
                    "error_message": error_message,
                    "duration_ms": duration_ms,
                    "client_ip": client_ip,
                    "extra": json.dumps(extra or {}, ensure_ascii=False, default=str),
                },
            )
