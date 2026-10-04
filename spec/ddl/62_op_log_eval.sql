-- v2 Text-to-SQL 评测结果表
-- 执行角色：log_app，连接数据库：op_log

CREATE SCHEMA IF NOT EXISTS eval;

CREATE TABLE IF NOT EXISTS eval.eval_runs (
    run_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name varchar(128) NOT NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    total_duration_ms integer CHECK (total_duration_ms >= 0),
    total_cases integer NOT NULL CHECK (total_cases >= 0),
    sql_executable_count integer NOT NULL CHECK (sql_executable_count >= 0),
    sql_result_correct_count integer NOT NULL CHECK (sql_result_correct_count >= 0),
    answer_correct_count integer NOT NULL CHECK (answer_correct_count >= 0),
    task_success_count integer NOT NULL CHECK (task_success_count >= 0),
    avg_sql_latency_ms numeric(12,3),
    avg_total_latency_ms numeric(12,3),
    input_tokens bigint,
    output_tokens bigint,
    token_cost_unavailable boolean NOT NULL DEFAULT true,
    summary jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS eval.eval_case_results (
    result_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id uuid NOT NULL REFERENCES eval.eval_runs(run_id) ON DELETE CASCADE,
    case_id varchar(64) NOT NULL,
    question text NOT NULL,
    generated_sql text,
    result_status varchar(16) NOT NULL CHECK (result_status IN ('SUCCESS', 'FAILED', 'CANCELED')),
    sql_executable boolean NOT NULL,
    sql_result_correct boolean NOT NULL DEFAULT false,
    answer_correct boolean NOT NULL DEFAULT false,
    task_success boolean NOT NULL DEFAULT false,
    sql_latency_ms integer CHECK (sql_latency_ms >= 0),
    total_latency_ms integer CHECK (total_latency_ms >= 0),
    input_tokens bigint,
    output_tokens bigint,
    token_cost_unavailable boolean NOT NULL DEFAULT true,
    error_code varchar(64),
    error_message text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_eval_case_results_run_case UNIQUE (run_id, case_id)
);

CREATE INDEX IF NOT EXISTS idx_eval_case_results_run
    ON eval.eval_case_results (run_id);

-- 阻止更新或删除评测结果
CREATE OR REPLACE FUNCTION eval.prevent_eval_modify()
RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION '评测结果只允许插入，不允许更新或删除';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_eval_runs_append_only ON eval.eval_runs;
CREATE TRIGGER trg_eval_runs_append_only
BEFORE UPDATE OR DELETE ON eval.eval_runs
FOR EACH ROW EXECUTE FUNCTION eval.prevent_eval_modify();

DROP TRIGGER IF EXISTS trg_eval_case_results_append_only ON eval.eval_case_results;
CREATE TRIGGER trg_eval_case_results_append_only
BEFORE UPDATE OR DELETE ON eval.eval_case_results
FOR EACH ROW EXECUTE FUNCTION eval.prevent_eval_modify();
