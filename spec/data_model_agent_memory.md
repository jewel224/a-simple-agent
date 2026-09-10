# agent_memory 数据模型

## 1. 用途

`agent_memory` 用于保存 AI Agent 会话、消息和跨会话记忆，支持文本、向量与 JSONB 元数据。

## 2. 表结构

### agent_sessions 会话表

字段：

- `session_id UUID PRIMARY KEY`
- `agent_name VARCHAR(64) NOT NULL`
- `user_key VARCHAR(64)`
- `session_title VARCHAR(255)`
- `session_status VARCHAR(16) NOT NULL DEFAULT 'active'`
- `metadata JSONB NOT NULL DEFAULT '{}'`
- `started_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `ended_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

### agent_messages 消息表

字段：

- `message_id BIGINT PRIMARY KEY`
- `session_id UUID NOT NULL REFERENCES agent_sessions(session_id) ON DELETE CASCADE`
- `message_no INTEGER NOT NULL`
- `role VARCHAR(16) NOT NULL` user/assistant/tool/system
- `content TEXT NOT NULL`
- `tool_name VARCHAR(128)`
- `tool_args JSONB`
- `model_name VARCHAR(128)`
- `token_usage JSONB`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

唯一约束：`UNIQUE(session_id, message_no)`。

### agent_memories 记忆表

字段：

- `memory_id BIGINT PRIMARY KEY`
- `scope_type VARCHAR(16) NOT NULL` global/session/user
- `memory_type VARCHAR(32) NOT NULL` preference/task_state/semantic/episode/summary
- `session_id UUID REFERENCES agent_sessions(session_id) ON DELETE CASCADE`
- `source_message_id BIGINT REFERENCES agent_messages(message_id) ON DELETE SET NULL`
- `content TEXT NOT NULL`
- `embedding vector`
- `model_name VARCHAR(128)`
- `model_version VARCHAR(64)`
- `dimensions INTEGER`
- `confidence NUMERIC(4,3)`
- `importance SMALLINT`
- `metadata JSONB NOT NULL DEFAULT '{}'`
- `expires_at TIMESTAMPTZ`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`

约束：当向量存在时 `vector_dims(embedding) = dimensions`。
