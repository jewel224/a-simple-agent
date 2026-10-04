# a-simple-agent 本地 PostgreSQL 多用途学习数据库

## 1. 项目目标

搭建一个本机可运行的 PostgreSQL 18.6 学习环境，同时承担四类职责：

1. 业务数据库：`shop_dw`，模拟手机购物 App 的星型数仓。
2. Embedding 数据库：`embedding_store`，存放文档分块与向量。
3. AI Agent 上下文记忆库：`agent_memory`，存放会话、消息和记忆。
4. 操作日志库：`op_log`，存放 Agent、脚本和 API 产生的操作日志。

四类数据按 database 隔离，并配置独立登录角色，避免业务数据、向量数据、Agent 记忆与日志互相干扰。

## 2. 总体拓扑

```text
本机 PostgreSQL 18.6（服务 postgresql-x64-18，端口 5432）
|
|-- shop_dw          角色 shop_app，9 张维度表 + 7 张事实表
|-- embedding_store  角色 embed_app，documents/chunks/embeddings
|-- agent_memory     角色 memory_app，sessions/messages/memories
`-- op_log          角色 log_app，audit.operation_log
```

角色初始化脚本、数据库 DDL、种子数据和自检脚本都放在 `spec/`；验收测试脚本放在 `test/`。

## 3. 初始化流程

1. `spec/scripts/download_dependencies.ps1` 下载 PostgreSQL 与 pgvector 安装包。
2. `spec/scripts/install_postgresql.ps1` 安装 PostgreSQL 并部署 pgvector。
3. `spec/scripts/init_all.ps1` 创建角色、4 个 database、扩展、表结构、基础种子、扩展 mock 数据与退款扩展种子。
4. `test/run_all.ps1` 执行环境、隔离、结构、业务、向量、Agent 记忆和日志测试。

所有 SQL 文件使用 UTF-8 编码，执行时设置 `PGCLIENTENCODING=UTF8`，避免中文乱码。

## 4. 目录说明

```text
a-simple-agent/
|-- .env.example            本机密码模板
|-- .env                    本机密码，已忽略，不提交
|-- .gitignore
|-- README.md               项目入口文档
|-- SECURITY.md             安全说明
|-- LICENSE                 开源许可证
|-- requirements.txt        Python 依赖清单
|-- app/
|   `-- assistant_order_bot.py  订单助手入口
|-- scripts/
|   |-- check_environment.ps1
|   |-- start_agent.ps1
|   `-- reset_mock_data.ps1
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
|-- spec/
|   |-- architecture.md
|   |-- environment.md
|   |-- isolation_and_security.md
|   |-- data_model_shop_dw.md
|   |-- data_model_embedding_store.md
|   |-- data_model_agent_memory.md
|   |-- data_model_operation_log.md
|   |-- ddl/
|   `-- scripts/
`-- test/
    |-- test_plan.md
    |-- scripts/
    `-- sql/
```

`downloads/` 目录用于保存外部安装包，已被 `.gitignore` 忽略，便于源码分享。

## 5. Agent 应用层

订单助手位于 `app/assistant_order_bot.py`，使用 DashScope qwen-agent 将自然语言问题转换为 SQL，通过 `exc_sql` 查询 `shop_dw`，再结合查询结果生成业务回答。详细设计见 `spec/agent_app.md`。

## 6. v2 治理链路

v2 新增 `app/governance/` 与 FastAPI 服务，用于简历项目《Text-to-SQL Agent 数据问答与治理系统》的治理版实现。总体拓扑扩展为：

```text
FastAPI /api/v1/query
|
|-- SQLGuard / shop_ro
|-- governance semantic metadata + pgvector
|-- agent_memory sessions/messages
`-- op_log audit.operation_log
```

新增核心模块：

| 模块 | 职责 |
| --- | --- |
| `app/governance/api.py` | FastAPI 入口、健康检查、API Key 校验 |
| `app/governance/sql_guard.py` | SQL 解析、白名单、敏感字段拦截 |
| `app/governance/sql_executor.py` | `shop_ro` 只读执行、超时、行数限制 |
| `app/governance/masking.py` | 应用层二次脱敏 |
| `app/governance/semantic.py` | 语义检索与动态 Prompt |
| `app/governance/memory.py` | 会话与消息持久化 |
| `app/governance/audit.py` | 请求审计 |
| `app/governance/evaluation.py` | 50 条评测集执行与结果落库 |

治理设计详见 `spec/governance.md`。

## 7. Docker 拓扑

`docker-compose.yml` 提供两个服务：

| 服务 | 镜像/基础 | 说明 |
| --- | --- | --- |
| `db` | `pgvector/pgvector:pg18` | PostgreSQL 18、pgvector、项目 DDL 初始化 |
| `api` | `python:3.13-slim` | FastAPI + uvicorn 治理服务 |

旧版 `app/assistant_order_bot.py` 仍在本机 Python 环境运行，不进入 Docker 服务。
