-- op_log：应用操作日志
-- 执行角色：log_app，连接数据库：op_log

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.operation_log (
    log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    source_system varchar(32) NOT NULL,
    service_name varchar(64) NOT NULL,
    action varchar(128) NOT NULL,
    actor_id varchar(64),
    trace_id uuid NOT NULL,
    session_id varchar(64),
    object_type varchar(64),
    object_id varchar(128),
    request_payload jsonb,
    response_payload jsonb,
    result_status varchar(16) NOT NULL CHECK (result_status IN ('SUCCESS', 'FAILED', 'CANCELED')),
    error_code varchar(32),
    error_message text,
    duration_ms integer CHECK (duration_ms >= 0),
    client_ip inet,
    extra jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE audit.operation_log IS 'Agent、脚本与 API 操作日志，只允许追加';

CREATE INDEX IF NOT EXISTS idx_op_log_source_time
    ON audit.operation_log (source_system, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_op_log_trace
    ON audit.operation_log (trace_id);

CREATE INDEX IF NOT EXISTS idx_op_log_session_time
    ON audit.operation_log (session_id, occurred_at DESC);

-- 阻止更新和删除日志
CREATE OR REPLACE FUNCTION audit.prevent_operation_log_modify()
RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION '操作日志只允许插入，不允许更新或删除';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_operation_log_append_only ON audit.operation_log;

CREATE TRIGGER trg_operation_log_append_only
BEFORE UPDATE OR DELETE ON audit.operation_log
FOR EACH ROW EXECUTE FUNCTION audit.prevent_operation_log_modify();

COMMENT ON FUNCTION audit.prevent_operation_log_modify() IS '禁止更新或删除操作日志';
