-- agent_memory 演示种子数据
-- 执行角色：memory_app，连接数据库：agent_memory

TRUNCATE TABLE public.agent_memories, public.agent_messages, public.agent_sessions RESTART IDENTITY CASCADE;

INSERT INTO public.agent_sessions (
    session_id,
    agent_name,
    user_key,
    session_title,
    session_status
) OVERRIDING SYSTEM VALUE
VALUES
    ('11111111-1111-1111-1111-111111111111', 'learning-agent', 'U10001', '学习 PostgreSQL 数据模型', 'active');

INSERT INTO public.agent_messages (
    message_id,
    session_id,
    message_no,
    role,
    content,
    model_name,
    token_usage
) OVERRIDING SYSTEM VALUE
VALUES
    (1, '11111111-1111-1111-1111-111111111111', 1, 'user',
     '请解释一下数据库里外键的作用。', 'qwen-plus', '{"prompt_tokens": 10, "completion_tokens": 8}'),
    (2, '11111111-1111-1111-1111-111111111111', 2, 'assistant',
     '外键用来保证两张表之间的引用关系有效，例如订单明细必须指向已存在的订单。', 'qwen-plus',
     '{"prompt_tokens": 10, "completion_tokens": 18}'),
    (3, '11111111-1111-1111-1111-111111111111', 3, 'user',
     '以后请默认用中文回答。', 'qwen-plus', NULL);

INSERT INTO public.agent_memories (
    memory_id,
    scope_type,
    memory_type,
    session_id,
    source_message_id,
    content,
    embedding,
    model_name,
    model_version,
    dimensions,
    confidence,
    importance,
    metadata
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'global', 'preference', NULL, 3,
     '用户偏好默认使用中文回答技术问题。',
     '[0.20, 0.10, 0.90]'::vector, 'demo-embedding', 'v1', 3, 0.95, 8,
     '{"source": "explicit_feedback"}'),
    (2, 'session', 'summary', '11111111-1111-1111-1111-111111111111', 2,
     '本会话讨论了数据库外键与引用完整性的概念。',
     '[0.80, 0.20, 0.10]'::vector, 'demo-embedding', 'v1', 3, 0.90, 6,
     '{"source": "session_summary"}');

SELECT setval(pg_get_serial_sequence('public.agent_messages', 'message_id'), (SELECT max(message_id) FROM public.agent_messages));
SELECT setval(pg_get_serial_sequence('public.agent_memories', 'memory_id'), (SELECT max(memory_id) FROM public.agent_memories));
