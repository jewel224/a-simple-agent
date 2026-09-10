-- 环境测试：版本、数据库、角色

DO $$
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION 'PostgreSQL version must be 18 or newer, current %', current_setting('server_version');
    END IF;
END;
$$;

DO $$
DECLARE
    database_count integer;
    role_count integer;
BEGIN
    SELECT count(*) INTO database_count
    FROM pg_database
    WHERE datname IN ('shop_dw', 'embedding_store', 'agent_memory', 'op_log');

    IF database_count <> 4 THEN
        RAISE EXCEPTION 'expected 4 databases, got %', database_count;
    END IF;

    SELECT count(*) INTO role_count
    FROM pg_roles
    WHERE rolname IN ('shop_app', 'embed_app', 'memory_app', 'log_app');

    IF role_count <> 4 THEN
        RAISE EXCEPTION 'expected 4 roles, got %', role_count;
    END IF;
END;
$$;
