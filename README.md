# a-simple-agent

一个面向数据仓库学习的本地 Text-to-SQL 订单助手项目。

项目将手机购物 App 的 mock 数仓、AI Agent、向量库、Agent 记忆和操作日志整合在同一套 PostgreSQL 环境中，并通过 DashScope + qwen-agent 查询 `shop_dw` 数据。

## 1. 项目组成

| 模块 | 说明 |
| --- | --- |
| `app/assistant_order_bot.py` | 订单助手，使用 qwen-agent + Text-to-SQL 查询业务数仓 |
| `shop_dw` | 手机购物 App 星型数仓，9 张维度表 + 7 张事实表 |
| `embedding_store` | 文档分块与 pgvector 向量数据 |
| `agent_memory` | Agent 会话、消息与长期记忆 |
| `op_log` | 应用操作日志 |
| `spec/` | 数据库、安装、隔离、数据模型设计文档 |
| `test/` | 初始化环境与数据场景验收测试 |

`shop_dw` 当前包含约 2.2 万订单，覆盖 2025-01-01 至 2026-09-10，包含全国地区、日常类目、大促、共享地址、共享手机号和多商家经营等模拟场景。

## Agent 流程图

![a-simple-agent Agent 流程图](docs/agent_flow.png)

源文件：[Mermaid](docs/agent_flow.mmd) / [SVG](docs/agent_flow.svg)

## 2. 文档导航

| 文档 | 说明 |
| --- | --- |
| `spec/architecture.md` | 总体架构与初始化流程 |
| `spec/environment.md` | PostgreSQL 下载、安装、pgvector 与初始化 |
| `spec/isolation_and_security.md` | 四库隔离与权限设计 |
| `spec/data_model_shop_dw.md` | 业务数仓 16 表模型与 mock 场景 |
| `spec/data_model_embedding_store.md` | 文档与向量表 |
| `spec/data_model_agent_memory.md` | Agent 会话与记忆表 |
| `spec/data_model_operation_log.md` | 操作日志表 |
| `spec/agent_app.md` | 订单助手应用设计与安全边界 |
| `docs/getting_started.md` | 零基础安装与启动 |
| `docs/concept_map.md` | 数仓与 Agent 概念地图 |
| `docs/demo.md` | 演示问题、SQL 和预期结果 |
| `docs/operations.md` | 启停、查询、重置操作 |
| `docs/troubleshooting.md` | 常见错误与修复 |
| `SECURITY.md` | 密码与数据安全说明 |
| `docs/environment_requirements.md` | 系统、Python、PostgreSQL 与网络要求 |
| `test/test_plan.md` | 验收测试说明 |

## 3. 环境准备

详细要求见 `docs/environment_requirements.md`。

### 3.1 PostgreSQL 与 pgvector

```powershell
Copy-Item .env.example .env
# 编辑 .env，填写 PostgreSQL 与 DashScope 配置

powershell -ExecutionPolicy Bypass -File .\spec\scripts\download_dependencies.ps1
powershell -ExecutionPolicy Bypass -File .\spec\scripts\install_postgresql.ps1
powershell -ExecutionPolicy Bypass -File .\spec\scripts\init_all.ps1
```

### 3.2 Python 环境

推荐 Python 3.13。

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r .\requirements.txt
```

### 3.3 `.env` 配置

`.env` 已被 `.gitignore` 忽略，不会随源码分享。

```dotenv
MOCK_PG_SUPER_PASSWORD=你的 postgres 超级用户密码
MOCK_PG_APP_PASSWORD=你的应用角色密码

MOCK_PG_HOST=localhost
MOCK_PG_PORT=5432
MOCK_PG_USER=shop_app
MOCK_PG_PASSWORD=你的 shop_app 密码
MOCK_PG_DB=shop_dw

DASHSCOPE_API_KEY=你的 DashScope API Key
```

## 4. 启动订单助手

```powershell
.\.venv\Scripts\Activate.ps1
python .\app\assistant_order_bot.py
```

默认启动 qwen-agent WebUI。Agent 会根据用户问题生成 SQL，通过 `exc_sql` 工具查询 `shop_dw`，然后返回自然语言分析结果。

示例问题：

- 2025 年 11 月各品类的订单金额排名情况。
- 2025 年 618 期间各渠道的订单量和支付金额统计。
- 2026 年 1-8 月每月的退款金额和退款率趋势。
- 哪些省份的订单量最高。
- 哪些商家和类目在双11期间表现最好。

## 5. 验收测试

```powershell
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
```

测试覆盖环境、四库隔离、16 张业务表结构、mock 数据场景、向量检索、Agent 记忆和操作日志。

## 6. 目录结构

```text
a-simple-agent/
|-- .env.example
|-- .gitignore
|-- README.md
|-- SECURITY.md
|-- LICENSE
|-- requirements.txt
|-- app/
|   `-- assistant_order_bot.py
|-- docs/
|   |-- agent_flow.mmd
|   |-- agent_flow.svg
|   |-- agent_flow.png
|   |-- getting_started.md
|   |-- environment_requirements.md
|   |-- concept_map.md
|   |-- demo.md
|   |-- operations.md
|   `-- troubleshooting.md
|-- scripts/
|   |-- check_environment.ps1
|   |-- start_agent.ps1
|   `-- reset_mock_data.ps1
|-- downloads/              外部安装包，已忽略
|-- spec/
|   |-- architecture.md
|   |-- environment.md
|   |-- isolation_and_security.md
|   |-- data_model_*.md
|   |-- ddl/                角色、DDL 与 mock 种子 SQL
|   `-- scripts/            下载、安装、初始化脚本
`-- test/
    |-- test_plan.md
    |-- scripts/run_all.ps1
    `-- sql/                分库验收 SQL
```

## 7. 分享注意事项

- `.env` 包含数据库密码和 DashScope Key，禁止提交。
- `downloads/` 包含大型安装包，已被忽略，分享前可删除。
- 接收方通过 `.env.example` 创建自己的 `.env`。
- `shop_dw` 的 mock 数据由 `spec/ddl/` 下的 SQL 生成，不依赖本地数据库文件。