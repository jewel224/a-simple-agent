# a-simple-agent 升级版改进计划

## 1. 文档目的

本文档用于整理当前 `a-simple-agent` 项目在面试展示、开源分享和后续升级中的不足，作为 v2 版本的设计输入。

当前项目已经完成：

- PostgreSQL mock 数仓。
- 四库隔离。
- 基础 Agent Text-to-SQL。
- 安装、初始化和测试脚本。
- 新手文档与小红书营销素材。

升级版重点不是继续堆功能，而是提升正确性、安全性、可评估性、可观测性和工程化程度。

## 2. 当前主要问题

| 优先级 | 问题 | 影响 |
| --- | --- | --- |
| P0 | Agent 可以执行任意 SQL | 可能修改、删除或删除表 |
| P0 | 缺少只读数据库角色 | Agent 权限过大 |
| P0 | 没有 Text-to-SQL 评测集 | 无法证明 Agent 回答可靠 |
| P1 | 模型生成的 SQL 没有写入操作日志 | 无法追溯和复盘 |
| P1 | Prompt 中的 schema 是手工复制 | schema 漂移风险 |
| P1 | Agent 未使用 agent_memory 数据库 | 没有长期记忆和多轮上下文管理 |
| P1 | Agent 未使用 embedding_store 数据库 | 没有知识检索能力 |
| P1 | 缺少 SQL 结果合理性校验 | 结果错误可能被当作正确答案 |
| P1 | 缺少 LLM token、延迟、成本统计 | 无法评估性能与成本 |
| P2 | Python 层缺少单元测试 | 只测数据库，未测 Agent 工具 |
| P2 | 没有数据库迁移工具 | schema 变更不可追溯 |
| P2 | 事实表缺少业务索引 | 数据量增大后查询会变慢 |
| P2 | 缺少 Docker Compose | 环境依赖本地手工安装 |
| P2 | 缺少 CI/CD | 不能自动验证提交 |
| P2 | 缺少 API 服务和前端解耦 | WebUI 和 Agent 耦合在一起 |
| P2 | 缺少备份、恢复和监控说明 | 不适合长期使用 |
| P2 | mock 数据生成代码较长且不可复用 | 难以扩展新场景 |

## 3. P0：安全与正确性

### 3.1 数据库权限最小化

当前问题：

- `shop_app` 是 `shop_dw` 的 owner。
- Agent 使用 `shop_app` 查询。
- 理论上可以执行写操作。

升级方案：

- 新增 `shop_ro` 只读角色。
- 只授予 `SELECT` 权限。
- Agent 使用 `shop_ro` 连接。
- 初始化和管理仍使用 owner 角色。
- 测试中验证 `shop_ro` 无法执行 `INSERT`、`UPDATE`、`DELETE`、`DROP`。

### 3.2 SQL 只读校验

升级方案：

- 只允许 `SELECT` 和 `WITH` 开头的单条 SQL。
- 禁止多语句、注释和写操作关键词。
- 禁止 `INTO`、`UPDATE`、`DELETE`、`INSERT`、`DROP`、`ALTER`、`TRUNCATE`、`GRANT`、`REVOKE`。
- 使用 SQL 解析器或关键字白名单进行校验。
- 数据库连接设置只读事务。
- 设置查询超时和最大返回行数。

验收标准：

- Agent 尝试写操作时工具直接拒绝。
- 即使绕过应用校验，数据库角色也没有写权限。

## 4. P0：Text-to-SQL 评测

### 4.1 评测集设计

建议建立 50 条业务问题，覆盖：

- 订单量统计。
- 客单价。
- 省份排名。
- 品类销售额。
- 支付方式。
- 退款率。
- 大促对比。
- 时间范围过滤。
- 多表关联。
- 聚合和排序。

每个问题包含：

- 自然语言问题。
- 标准 SQL。
- 标准结果集。
- 必要表。
- 必要字段。
- 正确回答要点。

### 4.2 评测指标

| 指标 | 说明 |
| --- | --- |
| 执行成功率 | SQL 可以正常执行的比例 |
| 结果集正确率 | 返回结果和标准结果一致的比例 |
| 列正确率 | 选择字段正确的比例 |
| 过滤正确率 | 时间和业务条件正确的比例 |
| 聚合正确率 | GROUP BY 和聚合字段正确的比例 |

### 4.3 自动化评测

- 将问题集保存为 JSON 或 YAML。
- 批量调用 Agent 工具。
- 比较返回结果。
- 输出评测报告。
- 将评测纳入 CI。

## 5. P1：Agent 能力升级

### 5.1 Agent Memory

当前状态：

- `agent_memory` 数据库已经建立。
- Agent 尚未使用记忆表。

升级方案：

- 按 `session_id` 保存对话摘要。
- 保存用户偏好。
- 保存常用分析指标和术语。
- 在新会话中检索相关记忆。
- 设计记忆更新、过期和冲突规则。

### 5.2 Embedding 与 RAG

当前状态：

- `embedding_store` 已经建立。
- Agent 尚未使用向量检索。

升级方案：

- 将表结构文档和 SQL 示例向量化。
- 用户问题先做语义检索。
- 将检索到的表和示例注入 Prompt。
- 降低模型因找不到字段而生成错误 SQL 的概率。

### 5.3 结果合理性校验

在 Agent 返回答案前增加校验：

- 结果是否为空。
- 金额是否非负。
- 订单量是否异常。
- 百分比是否在合理范围。
- 返回行数是否超过预期。
- 当前 SQL 是否与问题意图一致。

## 6. P1：可观测性

### 6.1 Agent 日志

需要记录：

- 用户问题。
- Agent 生成 SQL。
- 是否执行成功。
- 返回行数。
- 执行耗时。
- token 使用量。
- 模型名称。
- trace_id 和 session_id。

写入位置：

- `op_log.audit.operation_log`
- 或独立 `agent_run` 表。

### 6.2 监控指标

建议新增：

- 平均 SQL 执行耗时。
- SQL 失败率。
- LLM 平均耗时。
- token 成本。
- 评测集通过率。
- 各类错误数量。

## 7. P2：数据工程升级

### 7.1 数据库迁移

从手工 DDL 改为 Alembic：

- 初始化版本。
- 每次 schema 变更都有迁移文件。
- 支持升级和回滚。
- 测试迁移在干净数据库上执行。

### 7.2 数据索引

针对常用查询建立索引：

- `fact_order(date_key, order_status)`
- `fact_order(user_key, date_key)`
- `fact_order_item(product_key, date_key)`
- `fact_order_item(merchant_key, date_key)`
- `fact_payment(order_key, date_key)`
- `fact_refund(order_key, date_key)`
- `fact_app_event(user_key, date_key, event_type)`
- `fact_logistics_trace(logistics_order_key, trace_time DESC)`

### 7.3 Mock 数据生成

当前生成逻辑集中在两个大型 SQL 文件中。

升级方案：

- 拆分为可组合的生成模块。
- 支持选择数据规模。
- 支持指定时间范围。
- 支持随机种子。
- 生成过程写入日志。
- 增加数据质量校验。

### 7.4 数据质量规则

- 订单实付金额必须非负。
- 订单明细金额必须小于或等于商品原价乘数量。
- 支付金额不能超过订单实付金额。
- 退款金额不能超过支付金额。
- 物流运单必须关联有效订单。
- 用户、商品、商家、地区外键不能悬空。

## 8. P2：工程化与部署

### 8.1 项目结构升级

建议 v2 结构：

```text
a-simple-agent/
|-- app/
|   |-- api/                 FastAPI 接口
|   |-- agent/               Agent 与工具
|   |-- core/                配置、日志、数据库
|   |-- schemas/             数据模型
|   |-- services/            业务服务
|   `-- tools/               查询、检索、可视化工具
|-- migrations/              Alembic
|-- tests/
|   |-- unit/
|   |-- integration/
|   `-- eval/
|-- scripts/
|-- docker/
|-- docs/
|-- data/
|-- spec/
`-- pyproject.toml
```

### 8.2 API 与前端分离

升级方案：

- FastAPI 提供服务端接口。
- Agent 作为后台服务。
- 前端可独立使用 WebUI 或 Streamlit。
- 通过接口实现会话和查询历史。

### 8.3 Docker Compose

提供本地一键环境：

- PostgreSQL 18 + pgvector。
- Agent API 服务。
- 可选 pgAdmin。
- 数据卷持久化。
- `.env` 注入配置。

### 8.4 CI/CD

GitHub Actions：

- Python 语法检查。
- 单元测试。
- 数据库初始化测试。
- Text-to-SQL 评测。
- 构建 Docker 镜像。
- 自动生成 schema 校验。

### 8.5 备份与恢复

补充：

- `pg_dump` 备份脚本。
- 恢复脚本。
- 定时备份说明。
- 测试恢复流程。

## 9. v2 目标架构

```text
用户
  |
WebUI / API
  |
Agent 服务
  |-- 问题理解
  |-- 记忆检索
  |-- schema 检索
  |-- SQL 生成
  |-- SQL 校验
  |-- 只读查询
  |-- 结果校验
  `-- 可观测日志

数据层
  |-- shop_dw       业务数仓
  |-- embedding_store 知识向量
  |-- agent_memory   会话记忆
  `-- op_log         审计日志
```

## 10. v2 验收清单

- Agent 只能读取数据，不能写入或删除。
- SQL 评测集达到目标准确率。
- 所有 SQL 和 token 信息可追踪。
- schema 自动生成并校验。
- Agent 能使用历史记忆。
- 能通过向量检索找到相关表。
- 数据库初始化可重复。
- mock 数据规模可配置。
- Docker 一键启动。
- CI 自动跑测试和评测。
- 项目结构和文档清晰。