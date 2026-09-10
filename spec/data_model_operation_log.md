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
