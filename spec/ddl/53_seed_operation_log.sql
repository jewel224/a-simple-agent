-- op_log 演示种子数据
-- 执行角色：log_app，连接数据库：op_log

TRUNCATE TABLE audit.operation_log RESTART IDENTITY CASCADE;

INSERT INTO audit.operation_log (
    log_id,
    occurred_at,
    source_system,
    service_name,
    action,
    actor_id,
    trace_id,
    session_id,
    object_type,
    object_id,
    request_payload,
    response_payload,
    result_status,
    error_code,
    error_message,
    duration_ms,
    client_ip,
    extra
) OVERRIDING SYSTEM VALUE
VALUES
    (1, '2026-09-09 10:00:00+08', 'agent', 'learning-agent', 'query_memory',
     'U10001', '22222222-2222-2222-2222-222222222222', 'SESS000009', 'agent_memory', 'memory',
     '{"keyword": "外键"}', '{"top_k": 3}', 'SUCCESS', NULL, NULL, 35, '127.0.0.1',
     '{"source": "demo"}'),
    (2, '2026-09-09 10:01:00+08', 'etl', 'shop_dw_loader', 'load_order_fact',
     'etl_batch_1', '33333333-3333-3333-3333-333333333333', NULL, 'fact_order', 'batch_20260909',
     '{"batch_id": "20260909"}', '{"rows": 120}', 'SUCCESS', NULL, NULL, 1800, '127.0.0.1',
     '{"job": "daily"}'),
    (3, '2026-09-09 10:02:00+08', 'api', 'sql_tool', 'execute_query',
     'api_user', '44444444-4444-4444-4444-444444444444', 'SESS000010', 'sql', 'query',
     '{"sql": "select 1"}', NULL, 'FAILED', 'PERMISSION_DENIED', '用户无权读取该表', 12, '127.0.0.1',
     '{"retry": false}');

SELECT setval(pg_get_serial_sequence('audit.operation_log', 'log_id'), (SELECT max(log_id) FROM audit.operation_log));
