-- agent_memory：AI Agent 会话与记忆
-- 执行角色：memory_app，连接数据库：agent_memory

CREATE TABLE IF NOT EXISTS public.agent_sessions (
    session_id uuid PRIMARY KEY,
    agent_name varchar(64) NOT NULL,
    user_key varchar(64),
    session_title varchar(255),
    session_status varchar(16) NOT NULL DEFAULT 'active'
        CHECK (session_status IN ('active', 'ended', 'archived')),
    metadata jsonb NOT NULL DEFAULT '{}',
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.agent_sessions IS 'Agent 会话表';

CREATE TABLE IF NOT EXISTS public.agent_messages (
    message_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES public.agent_sessions(session_id) ON DELETE CASCADE,
    message_no integer NOT NULL,
    role varchar(16) NOT NULL CHECK (role IN ('user', 'assistant', 'tool', 'system')),
    content text NOT NULL,
    tool_name varchar(128),
    tool_args jsonb,
    model_name varchar(128),
    token_usage jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_agent_messages_session_no UNIQUE (session_id, message_no)
);

COMMENT ON TABLE public.agent_messages IS 'Agent 会话消息，一行一条消息';

CREATE TABLE IF NOT EXISTS public.agent_memories (
    memory_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scope_type varchar(16) NOT NULL CHECK (scope_type IN ('global', 'session', 'user')),
    memory_type varchar(32) NOT NULL
        CHECK (memory_type IN ('preference', 'task_state', 'semantic', 'episode', 'summary')),
    session_id uuid REFERENCES public.agent_sessions(session_id) ON DELETE CASCADE,
    source_message_id bigint REFERENCES public.agent_messages(message_id) ON DELETE SET NULL,
    content text NOT NULL,
    embedding vector,
    model_name varchar(128),
    model_version varchar(64),
    dimensions integer,
    confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
    importance smallint CHECK (importance BETWEEN 1 AND 10),
    metadata jsonb NOT NULL DEFAULT '{}',
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_agent_memories_dimension CHECK (
        (embedding IS NULL AND dimensions IS NULL)
        OR (embedding IS NOT NULL AND dimensions IS NOT NULL AND vector_dims(embedding) = dimensions)
    )
);

COMMENT ON TABLE public.agent_memories IS 'Agent 长期与短期记忆，支持文本、向量和过期时间';
