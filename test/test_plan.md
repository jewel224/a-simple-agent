# 测试计划

## 1. 测试目标

验证本地 PostgreSQL 18.6 学习数据库的环境、隔离、表结构、业务数据、向量检索、Agent 记忆和操作日志都符合设计。

## 2. 执行前提

- PostgreSQL 18.6 已安装并启动。
- pgvector 0.8.6 已复制到 PostgreSQL 扩展目录。
- `spec/scripts/init_all.ps1` 已成功执行。
- `scripts/sync_governance_semantic.ps1` 已成功执行，治理语义层四类元数据向量均不为空。

## 3. 测试内容

| 文件 | 验证内容 |
| --- | --- |
| `sql/01_environment.sql` | 服务版本、4 个 database、4 个角色 |
| `sql/02_isolation.sql` | 四个角色只能连接自己的 database |
| `sql/03_shop_dw_structure.sql` | `shop_dw` 16 张表与主要约束 |
| `sql/04_shop_dw_business.sql` | 扩展 mock 数据规模、多地址/共享地址/共享手机号、类目订单量关系、大促、区域分布、物流状态同步 |
| `sql/05_embedding_store.sql` | 文档分块向量、cosine 查询 |
| `sql/06_agent_memory.sql` | 会话消息记忆、记忆关联 |
| `sql/07_operation_log.sql` | 日志插入、禁止 UPDATE/DELETE |

`run_all.ps1` 另外通过 psql 检查：

- `embedding_store`、`agent_memory` 中存在 `vector` 扩展。

业务库初始化后包含约 2.2 万订单规模：106 个地区、213 个用户、20 个商家、25 个类目、44 个商品、22307 个订单、22309 条订单明细、17809 条支付、14488 个物流运单、28977 条物流状态流水和 22310 条 App 事件。

扩展 mock 数据必须满足以下场景：

- 用户 1 有 3 个以上订单量差异明显的收件地址。
- 家庭共享地址由 2-4 个用户共同使用；公司共享地址由 20-200 个用户共同使用，但公司用户不共用手机号。
- 存在 10 个手机号各由 2 人共用，以及 5 个手机号各由 3 人共用。
- 商家总数不少于 20 个，且一个商家只经营一个大类。
- 女士相关订单量 > 婴童类 > 男士 > 家具家电。
- 618、双11、双12、双旦期间的订单量显著高于日常。
- 订单覆盖全国 31 个省份/自治区/直辖市，江浙沪订单占比偏高。
- 扩展订单事实覆盖到上海时区运行当日，不生成未来订单日期；退款发生日期不晚于当日。

## 4. 运行方式

```powershell
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
```

脚本优先读取项目根目录 `.env` 中的 `MOCK_PG_SUPER_PASSWORD` 与 `MOCK_PG_APP_PASSWORD`；若未创建 `.env`，也可以先设置同名环境变量再执行。

所有 SQL 文件在 `psql -v ON_ERROR_STOP=1` 下执行，任一测试失败立即返回非零退出码。`agent_memory` 与 `op_log` 数据量按种子下限验收，允许此前端到端请求追加的真实会话、消息和审计日志。

## 5. v2 治理测试

初始化后新增以下 SQL 验收：

| 文件 | 验证内容 |
| --- | --- |
| `sql/08_governance.sql` | `shop_ro` 只读权限、敏感字段拒绝访问、脱敏视图格式 |
| `sql/09_governance_metadata.sql` | 治理语义元数据、敏感级别、HNSW 索引、四类元数据向量完整性 |
| `sql/10_eval_tables.sql` | 评测结果表写入与 append-only 触发器 |

`run_all.ps1` 已按以下顺序执行：

1. Python 治理单元测试，包含 SQLGuard、评测指标、评测 CLI 与 Docker Compose 部署配置静态校验。
2. 原环境、隔离、结构、业务数据、向量、记忆和日志测试。
3. `shop_ro` 权限与脱敏测试。
4. `governance` 语义层测试。
5. `eval` 评测结果表测试。

Docker Compose 静态验收要求：数据库宿主机端口为 `5433:5432`；存在 one-shot `semantic-sync` 服务；API 依赖 `semantic-sync` 成功完成；初始化所需的两个数据库角色密码显式传入 `db` 容器。完整容器验收另行执行 `docker compose config` 和 `docker compose up --build`。

## 6. SQL 校验与应用测试

SQLGuard 手工或集成验收应覆盖：

- 拒绝 `INSERT`、`UPDATE`、`DELETE`、`DROP`、`TRUNCATE`。
- 拒绝多语句 SQL。
- 拒绝 `recipient_name`、`recipient_phone`、`shipping_detail_address`。
- 拒绝 `pg_sleep` 等非白名单函数。
- 允许品类金额、渠道汇总、省份订单量、商家大促表现等只读查询。
- 请求级语义范围只允许本次命中的表和字段；非敏感关联键、已命中维度表的业务展示字段和时间字段可用于 JOIN、分组和筛选，外层查询可引用已完成校验的 SELECT 或 CTE 输出别名。
- 请求级语义范围拒绝未命中表、未命中字段和 `SELECT *`。
- `fact_order_item` 拒绝 `SELECT *`，但不把 `COUNT(*)` 误判为通配查询。
- Agent 请求开始时会清空上一请求的工具结果；SQL 校验失败时工具返回结构化错误，且不写入成功工具结果。
- 评测 exact 结果比较按列名对齐，不把输出列顺序差异判为结果错误。

FastAPI 验收应覆盖：

1. 缺失或错误 `X-API-Key` 返回 401。
2. 正常问题返回答案、SQL、结果、`trace_id` 和脱敏结果。
3. 敏感字段请求安全拒绝时返回 200，`safety_rejected = true`，`sql = null`，结果为空，并写入审计；评测优先使用该结构化标志判定安全拒绝。
4. 非法 SQL 返回结构化错误且不执行数据库操作。
5. 超过最大行数时 `truncated = true`。
6. 每次请求产生 `op_log` 审计和 `agent_memory` 消息。
7. `/healthz` 返回四库连接状态、语义层向量就绪状态和缺失向量数量。

## 7. 评测验收

```powershell
python -m app.governance.eval_runner
python -m app.governance.eval_runner 12
```

验收点：

- 评测集固定为 50 条。
- 报告包含 SQL 可执行率、结果正确率、答案准确率、任务成功率、安全拒绝正确率、平均 SQL 延迟、平均总延迟和 token 用量。
- 47 条正常查询计算 SQL 可执行率和结果正确率；3 条安全拒绝案例只计算安全拒绝正确率；答案准确率和任务成功率使用全部 50 条案例。
- 每次运行写入 `op_log.eval.eval_runs`。
- 每个案例写入 `op_log.eval.eval_case_results`。
- 模型 usage 缺失时 `token_cost_unavailable = true`。

评测依赖 DashScope 真实模型访问；不需要网络时只执行 `test/scripts/run_all.ps1` 中的数据库验收。
