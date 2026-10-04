import json
import uuid
from typing import Any

from sqlalchemy import text

from app.governance.config import get_settings
from app.governance.db import DatabaseManager, get_database_manager


class MemoryService:
    """管理 Agent 会话和消息持久化。"""

    def __init__(self, db_manager: DatabaseManager | None = None):
        self.settings = get_settings()
        self.db_manager = db_manager or get_database_manager()

    def ensure_session(self, session_id: uuid.UUID | None, question: str) -> uuid.UUID:
        session_id = session_id or uuid.uuid4()
        title = question[:60]
        with self.db_manager.engine("memory").begin() as conn:
            exists = conn.execute(
                text("SELECT 1 FROM agent_sessions WHERE session_id = :session_id"),
                {"session_id": str(session_id)},
            ).scalar()
            if not exists:
                conn.execute(
                    text(
                        """
                        INSERT INTO agent_sessions (
                            session_id, agent_name, session_title, session_status, metadata
                        ) VALUES (
                            :session_id, 'governed_order_agent', :title, 'active',
                            CAST(:metadata AS jsonb)
                        )
                        """
                    ),
                    {
                        "session_id": str(session_id),
                        "title": title,
                        "metadata": json.dumps({"source": "fastapi"}, ensure_ascii=False),
                    },
                )
        return session_id

    def append_message(
        self,
        session_id: uuid.UUID,
        role: str,
        content: str,
        tool_name: str | None = None,
        tool_args: dict[str, Any] | None = None,
        model_name: str | None = None,
        token_usage: dict[str, Any] | None = None,
    ) -> None:
        with self.db_manager.engine("memory").begin() as conn:
            message_no = conn.execute(
                text(
                    """
                    SELECT COALESCE(MAX(message_no), 0) + 1
                    FROM agent_messages
                    WHERE session_id = :session_id
                    """
                ),
                {"session_id": str(session_id)},
            ).scalar_one()
            conn.execute(
                text(
                    """
                    INSERT INTO agent_messages (
                        session_id, message_no, role, content, tool_name,
                        tool_args, model_name, token_usage
                    ) VALUES (
                        :session_id, :message_no, :role, :content, :tool_name,
                        CAST(:tool_args AS jsonb), :model_name, CAST(:token_usage AS jsonb)
                    )
                    """
                ),
                {
                    "session_id": str(session_id),
                    "message_no": message_no,
                    "role": role,
                    "content": content,
                    "tool_name": tool_name,
                    "tool_args": json.dumps(tool_args, ensure_ascii=False) if tool_args else None,
                    "model_name": model_name,
                    "token_usage": json.dumps(token_usage, ensure_ascii=False) if token_usage else None,
                },
            )

    def recent_messages(self, session_id: uuid.UUID) -> list[dict[str, str]]:
        with self.db_manager.engine("memory").connect() as conn:
            rows = conn.execute(
                text(
                    """
                    SELECT role, content
                    FROM agent_messages
                    WHERE session_id = :session_id AND role IN ('user', 'assistant')
                    ORDER BY message_no DESC
                    LIMIT :limit
                    """
                ),
                {"session_id": str(session_id), "limit": self.settings.memory_message_limit},
            ).mappings().all()
        return [{"role": row["role"], "content": row["content"]} for row in reversed(rows)]
