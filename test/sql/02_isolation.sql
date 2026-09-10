-- 隔离测试：只允许对应角色连接自己的 database

DO $$
BEGIN
    IF has_database_privilege('shop_app', 'embedding_store', 'CONNECT') THEN
        RAISE EXCEPTION 'shop_app should not connect embedding_store';
    END IF;

    IF has_database_privilege('embed_app', 'shop_dw', 'CONNECT') THEN
        RAISE EXCEPTION 'embed_app should not connect shop_dw';
    END IF;

    IF has_database_privilege('memory_app', 'op_log', 'CONNECT') THEN
        RAISE EXCEPTION 'memory_app should not connect op_log';
    END IF;

    IF has_database_privilege('log_app', 'agent_memory', 'CONNECT') THEN
        RAISE EXCEPTION 'log_app should not connect agent_memory';
    END IF;

    IF NOT has_database_privilege('shop_app', 'shop_dw', 'CONNECT') THEN
        RAISE EXCEPTION 'shop_app should connect shop_dw';
    END IF;

    IF NOT has_database_privilege('embed_app', 'embedding_store', 'CONNECT') THEN
        RAISE EXCEPTION 'embed_app should connect embedding_store';
    END IF;

    IF NOT has_database_privilege('memory_app', 'agent_memory', 'CONNECT') THEN
        RAISE EXCEPTION 'memory_app should connect agent_memory';
    END IF;

    IF NOT has_database_privilege('log_app', 'op_log', 'CONNECT') THEN
        RAISE EXCEPTION 'log_app should connect op_log';
    END IF;
END;
$$;
