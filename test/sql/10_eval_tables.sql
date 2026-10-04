-- 评测结果表与 append-only 约束验收

DO $$
DECLARE
    test_run_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO eval.eval_runs (
        run_id, model_name, finished_at, total_duration_ms, total_cases,
        sql_executable_count, sql_result_correct_count, answer_correct_count,
        task_success_count, summary
    ) VALUES (
        test_run_id, 'test-model', now(), 0, 1, 1, 1, 1, 1,
        '{"purpose":"append-only-test"}'::jsonb
    );

    INSERT INTO eval.eval_case_results (
        run_id, case_id, question, generated_sql, result_status,
        sql_executable, sql_result_correct, answer_correct, task_success
    ) VALUES (
        test_run_id, 'append_only_test', 'append only test', 'SELECT 1', 'SUCCESS',
        true, true, true, true
    );

    BEGIN
        UPDATE eval.eval_runs SET total_cases = 2 WHERE run_id = test_run_id;
        RAISE EXCEPTION 'eval_runs 不应允许 UPDATE';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'unexpected privilege exception';
    WHEN OTHERS THEN
        IF SQLSTATE <> 'P0001' THEN
            RAISE EXCEPTION 'eval_runs UPDATE 应被业务触发器拒绝，SQLSTATE: %', SQLSTATE;
        END IF;
        RAISE NOTICE 'eval_runs UPDATE denied as expected';
    END;

    BEGIN
        DELETE FROM eval.eval_case_results WHERE run_id = test_run_id;
        RAISE EXCEPTION 'eval_case_results 不应允许 DELETE';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'unexpected privilege exception';
    WHEN OTHERS THEN
        IF SQLSTATE <> 'P0001' THEN
            RAISE EXCEPTION 'eval_case_results DELETE 应被业务触发器拒绝，SQLSTATE: %', SQLSTATE;
        END IF;
        RAISE NOTICE 'eval_case_results DELETE denied as expected';
    END;
END
$$;

SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'eval') AS eval_table_count,
    (SELECT COUNT(*) FROM eval.eval_runs WHERE model_name = 'test-model') AS test_run_count,
    (SELECT COUNT(*) FROM eval.eval_case_results WHERE case_id = 'append_only_test') AS test_case_count;
