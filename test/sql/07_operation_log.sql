-- op_log 日志测试

BEGIN;

DO $$
DECLARE
    log_count integer;
BEGIN
    SELECT count(*) INTO log_count FROM audit.operation_log;
    IF log_count <> 3 THEN
        RAISE EXCEPTION 'expected 3 operation logs, got %', log_count;
    END IF;

    INSERT INTO audit.operation_log (
        source_system,
        service_name,
        action,
        actor_id,
        trace_id,
        session_id,
        result_status,
        duration_ms,
        client_ip
    )
    VALUES (
        'test', 'test_service', 'test_action', 'tester',
        '55555555-5555-5555-5555-555555555555',
        'SESS_TEST', 'SUCCESS', 1, '127.0.0.1'
    );

    BEGIN
        UPDATE audit.operation_log
        SET result_status = 'FAILED'
        WHERE source_system = 'test';
        RAISE EXCEPTION 'expected update to be blocked';
    EXCEPTION
        WHEN raise_exception THEN
            NULL;
    END;

    BEGIN
        DELETE FROM audit.operation_log
        WHERE source_system = 'test';
        RAISE EXCEPTION 'expected delete to be blocked';
    EXCEPTION
        WHEN raise_exception THEN
            NULL;
    END;
END;
$$;

ROLLBACK;
