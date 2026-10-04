# op_log 数据模型

## 1. 用途

`op_log` 保存 Agent、脚本、API 和应用产生的操作日志，便于问题追溯与行为审计。

## 2. 表结构

### audit.operation_log 操作日志表

字段：

- `log_id BIGINT PRIMARY KEY`
- `occurred_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()`
- `source_system VARCHAR(32) NOT NULL`
- `service_name VARCHAR(64) NOT NULL`
- `action VARCHAR(128) NOT NULL`
- `actor_id VARCHAR(64)`
- `trace_id UUID NOT NULL`
- `session_id VARCHAR(64)`
- `object_type VARCHAR(64)`
- `object_id VARCHAR(128)`
- `request_payload JSONB`
- `response_payload JSONB`
- `result_status VARCHAR(16) NOT NULL`
- `error_code VARCHAR(32)`
- `error_message TEXT`
- `duration_ms INTEGER`
- `client_ip INET`
- `extra JSONB`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

约束：

- `result_status` 只能是 `SUCCESS`、`FAILED`、`CANCELED`。
- 禁止 UPDATE 和 DELETE，由触发器保证 append-only。

索引：

- `(source_system, occurred_at DESC)`
- `(trace_id)`
- `(session_id, occurred_at DESC)`

## 3. v2 评测结果表

`op_log` 新增 `eval` schema，继续遵循 append-only 原则。

### eval.eval_runs

保存一次评测运行：

- `run_id UUID`
- `model_name`
- `started_at` / `finished_at`
- `total_duration_ms`
- `total_cases`
- SQL 可执行数、SQL 结果正确数、答案正确数、任务成功数
- 平均 SQL 延迟、平均总延迟
- 输入 / 输出 token 数
- `token_cost_unavailable`
- `summary JSONB`

### eval.eval_case_results

保存每个案例：

- `run_id`、`case_id`
- 自然语言问题与生成 SQL
- `result_status`
- SQL 可执行、SQL 结果正确、答案正确、任务成功
- SQL 延迟、总延迟
- 输入 / 输出 token 数
- `token_cost_unavailable`
- 错误码与错误信息

两张表均由 `eval.prevent_eval_modify()` 触发器禁止 `UPDATE` 和 `DELETE`。
