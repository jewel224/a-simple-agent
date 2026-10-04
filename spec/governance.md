# 治理版 Text-to-SQL Agent 设计

## 1. 目标

v2 在保留 `app/assistant_order_bot.py` 旧版 WebUI 的基础上，新增 FastAPI 治理链路，用于把自然语言问题转换为受治理的 PostgreSQL 查询。

旧入口和 `exc_sql` 工具继续保留为 legacy 能力；v2 生产链路只使用 `governed_sql`。

## 2. 请求链路

```text
用户问题
  -> FastAPI /api/v1/query
  -> API Key 校验
  -> agent_memory 会话与消息
  -> embedding_store.governance 语义检索
  -> 动态 Prompt
  -> qwen-agent Function Calling
  -> SQLGuard 解析与白名单校验
  -> shop_ro 只读事务执行
  -> 行数限制与字段脱敏
  -> 自然语言回答
  -> agent_memory 消息 + op_log 审计
```

## 3. API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/healthz` | 检查四库连接，并返回治理语义层向量就绪状态与缺失数量 |
| `POST` | `/api/v1/query` | 受治理查询，必须携带 `X-API-Key` |

`/api/v1/query` 请求示例：

```json
{
  "question": "2025年11月各品类的订单金额排名情况",
  "session_id": null
}
```

成功响应包含：

- `trace_id`
- `session_id`
- `answer`
- `sql`
- `columns`
- `rows`
- `row_count`
- `truncated`
- `used_metadata`
- `latency_ms`
- `token_usage`

失败响应统一为：

```json
{
  "code": "INVALID_SQL",
  "message": "只允许单条 SELECT 或 WITH 查询"
}
```

## 4. SQL 治理

`app/governance/sql_guard.py` 使用 SQLGlot 解析 SQL，并强制以下规则：

- 只允许单条 `SELECT` 或 `WITH ... SELECT`。
- 拒绝 `INSERT`、`UPDATE`、`DELETE`、`DROP`、`ALTER`、`TRUNCATE`、多语句和管理命令。
- 只允许访问 `shop_dw` 的白名单表、白名单函数和脱敏视图。
- 每次请求会启用语义范围校验：只允许访问本次语义层命中的表、参考示例使用的表和命中字段。
- 日期键、订单键、商品键等非敏感结构性关联键允许用于 JOIN，避免语义字段裁剪破坏正常查询。
- 请求级语义范围内禁止 `SELECT *`，必须显式选择字段。
- 拒绝直接访问 `recipient_name`、`recipient_phone`、`shipping_detail_address`。
- `fact_order_item` 禁止 `SELECT *`。
- `pg_sleep` 等非白名单函数直接拒绝。

`app/governance/sql_executor.py` 使用 `shop_ro` 连接，执行只读事务，默认：

- `statement_timeout = 3000ms`
- 最多读取 `101` 行
- 返回最多 `100` 行
- 超过限制时 `truncated = true`

## 5. 权限与脱敏

`shop_ro` 是 v2 Agent 唯一使用的业务库角色。

`spec/ddl/05_shop_ro.sql` 与 `spec/ddl/60_shop_dw_governance.sql` 完成：

1. 创建并维护 `shop_ro` 登录角色。
2. 对安全业务表授予 `SELECT`。
3. 对 `fact_order_item` 的敏感字段不授权。
4. 创建 `v_fact_order_item_masked` 脱敏视图。
5. 数据库侧禁止敏感字段直读。

应用层 `masking.py` 继续根据结果列名对姓名、手机号和地址做二次脱敏。数据库权限是第一道防线，应用层脱敏是第二道防线。

## 6. 语义层

`embedding_store.governance` 保存四类元数据：

| 表 | 内容 |
| --- | --- |
| `table_metadata` | 表名、业务含义、粒度、状态、向量 |
| `column_metadata` | 字段含义、数据类型、敏感级别、可用角色、向量 |
| `metric_metadata` | 指标编码、口径、单位、粒度、计算模板、向量 |
| `query_example` | 自然语言问题、标准 SQL、使用表、向量 |

初始化 DDL 固化 shop_dw 的 16 张表和 204 个字段说明；向量需要单独执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync_governance_semantic.ps1
```

查询时会向量检索表、字段、指标和 SQL 示例，并组装动态 Prompt；检索 SQL 会过滤尚未生成向量的元数据。SQL 校验或执行失败时，工具会返回结构化错误给 Agent，促使模型修正 SQL 后重试；只有成功执行的结果才进入响应与审计。请求级 SQL 校验以命中的表和字段为基础，同时允许非敏感关联键、已命中维度表的业务展示字段和时间字段，以及外层查询引用的已校验 SELECT 或 CTE 输出别名。向量同步脚本使用显式事务提交，并在提交前校验四类元数据均不存在 NULL 向量。`/healthz` 返回 `semantic_metadata_ready` 与 `semantic_metadata_missing`，服务只有在四库可连接且语义向量完整时才返回 `ok`。

## 7. 记忆与审计

每次 Agent 请求开始前会清空当前上下文中的旧 `governed_sql` 工具结果；如果本次请求没有实际执行工具，服务会直接返回 `AGENT_EXECUTION_FAILED`，不会复用上一请求的 SQL 结果。

模型明确拒绝受限敏感字段请求且未执行 SQL 时，接口返回 200，`safety_rejected = true`，`sql = null`，查询结果为空；该结果同样写入记忆与审计。评测中的安全拒绝案例优先使用结构化 `safety_rejected` 判定。

每次成功或失败请求都会写入：

- `agent_memory.agent_sessions`
- `agent_memory.agent_messages`
- `op_log.audit.operation_log`

审计内容包括 trace、session、问题、最终 SQL、执行状态、行数、截断标记、SQL 延迟、总延迟、模型、token usage、错误和脱敏命中字段。

## 8. 评测

`app/governance/eval_cases.py` 固定包含 50 条案例，覆盖品类、渠道、省份、商家、支付方式、退款率、大促和敏感字段拒绝访问场景。省份订单量使用 `fact_order_item.shipping_province_name` 快照，并通过 `COUNT(DISTINCT order_key)` 去重。

评测结果写入：

- `op_log.eval.eval_runs`
- `op_log.eval.eval_case_results`

评测集拆分为 47 条正常查询和 3 条安全拒绝案例。`sql_executable_rate` 与 `sql_result_correct_rate` 只以 47 条正常查询为分母；`answer_accuracy` 与 `task_success_rate` 以全部 50 条为分母；`safety_rejection_correct_rate` 单独统计 3 条安全拒绝案例。

评测指标包括 SQL 可执行率、SQL 结果正确率、答案准确率、任务成功率、安全拒绝正确率、平均 SQL 延迟、平均总延迟和 token 用量。exact 结果比较按列名对齐，SELECT 输出列顺序不同但列名与数据一致时不判错。token 成本只依赖模型返回的真实 usage；缺失时标记 `unavailable`。完整评测集必须为 50 条；命令行可选 `limit` 只用于运行前 N 条子集，不改变每条案例的判定规则。

## 9. 服务与 Docker

本机启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_governed_api.ps1
```

FastAPI 使用进程级共享数据库连接池，Agent 工具、语义层、记忆、审计和健康检查复用同一组 Engine；应用退出时通过 lifespan 钩子统一释放。

容器启动：

```powershell
docker compose up --build
```

Docker Compose 包含：

- `db`：PostgreSQL 18 + pgvector，宿主机映射 `5433:5432`，避免与本机 PostgreSQL 5432 冲突。
- `semantic-sync`：one-shot 语义向量同步服务，执行 `app.governance.sync_semantic` 后退出。
- `api`：Python 3.13 + FastAPI + uvicorn。

启动顺序为：`db` 健康后执行数据库初始化脚本，创建四库与治理元数据；`semantic-sync` 调用 DashScope Embedding 生成语义向量，并在提交前校验四类元数据无 NULL 向量；`api` 只有在 `semantic-sync` 成功退出后才启动。语义同步失败时不做静默降级，API 不启动。

旧 qwen-agent WebUI 不进入 Docker 服务。

