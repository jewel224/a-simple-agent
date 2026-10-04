-- agent_memory 测试
-- 治理 API 端到端验收会追加真实会话与消息，因此这里校验种子下限而非精确数量。

DO $$
DECLARE
    session_count integer;
    message_count integer;
    memory_count integer;
BEGIN
    SELECT count(*) INTO session_count FROM public.agent_sessions;
    SELECT count(*) INTO message_count FROM public.agent_messages;
    SELECT count(*) INTO memory_count FROM public.agent_memories;

    IF session_count < 1 OR message_count < 3 OR memory_count < 2 THEN
        RAISE EXCEPTION 'agent seed counts missing: session=% message=% memory=%',
            session_count, message_count, memory_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.agent_memories
        WHERE memory_type = 'preference'
          AND source_message_id = 3
          AND content LIKE '%中文回答%'
    ) THEN
        RAISE EXCEPTION 'preference memory is not linked to source message';
    END IF;
END;
$$;
