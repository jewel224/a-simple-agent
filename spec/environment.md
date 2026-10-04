# 环境准备与安装

## 1. 下载依赖

运行下载脚本，脚本默认将文件保存到项目根目录的 `downloads/`：

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\download_dependencies.ps1
```

需要下载两个文件：

| 文件 | 来源 |
| --- | --- |
| `postgresql-18.6-3-windows-x64.exe` | EDB 官方 PostgreSQL 18.6 Windows x64 安装包 |
| `vector.v0.8.6-pg18.zip` | pgvector 0.8.6，PostgreSQL 18 Windows x64 预编译包 |

官方下载页：

- PostgreSQL：`https://www.enterprisedb.com/downloads/postgres-postgresql-downloads`
- pgvector Windows 预编译：`https://github.com/andreiramani/pgvector_pgsql_windows/releases`

## 2. 安装 PostgreSQL

默认安装参数：

| 配置项 | 默认值 |
| --- | --- |
| 安装目录 | `C:\Program Files\PostgreSQL\18` |
| 数据目录 | `C:\Program Files\PostgreSQL\18\data` |
| 服务名 | `postgresql-x64-18` |
| 端口 | `5432` |
| 超级用户 | `postgres` |

可以手动运行安装包按上述参数安装，也可以执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\install_postgresql.ps1
```

脚本会读取环境变量 `MOCK_PG_SUPER_PASSWORD`；未设置时交互式输入超级用户密码。

## 3. 安装 pgvector

安装脚本会把 zip 解压，并将 `vector.dll` 复制到 PostgreSQL 的 `lib` 目录，把 `vector.control` 和 `vector--*.sql` 复制到 `share/extension` 目录。

安装完成后手动验证：

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -h localhost -p 5432
```

在 `embedding_store` 和 `agent_memory` 数据库上创建扩展：

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## 4. 初始化项目数据库

推荐把本机密码放在项目根目录 `.env` 中。该文件已被 `.gitignore` 忽略，不会随源码分享。

首次使用复制模板：

```powershell
Copy-Item .env.example .env
```

编辑 `.env` 后，内容类似：

```dotenv
MOCK_PG_SUPER_PASSWORD=你的 postgres 超级用户密码
MOCK_PG_APP_PASSWORD=你的应用角色密码
```

安装、初始化、验收脚本会自动读取 `.env`；如果文件不存在，则继续读取同名环境变量，仍未配置时交互式输入。

然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\init_all.ps1
```

`init_all.ps1` 依次完成：

1. 创建 `shop_app`、`embed_app`、`memory_app`、`log_app` 角色。
2. 创建 `shop_dw`、`embedding_store`、`agent_memory`、`op_log` 数据库。
3. 撤销数据库 PUBLIC 默认连接权限，仅允许对应角色连接。
4. 在 `embedding_store`、`agent_memory` 中启用 `vector` 扩展。
5. 执行四库 DDL、基础演示数据与 `shop_dw` 扩展 mock 数据。
6. 输出数据库、表、扩展和 mock 数据自检结果。
7. 执行 `scripts/sync_governance_semantic.ps1` 生成治理语义向量；该步骤依赖 DashScope Embedding。

## 5. 常用脚本

```powershell
# 检查本机环境
powershell -ExecutionPolicy Bypass -File .\scripts\check_environment.ps1

# 启动订单助手 WebUI
powershell -ExecutionPolicy Bypass -File .\scripts\start_agent.ps1

# 只重置 shop_dw mock 数据
powershell -ExecutionPolicy Bypass -File .\scripts\reset_mock_data.ps1

# 运行完整验收测试
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
```

详细操作见 `docs/operations.md`，错误处理见 `docs/troubleshooting.md`。

## 6. 常见问题

- 安装包下载失败：检查网络后重新运行下载脚本。
- `psql` 不在 PATH：脚本使用完整路径 `C:\Program Files\PostgreSQL\18\bin\psql.exe`。
- 中文乱码：确保所有 psql 调用前设置 `$env:PGCLIENTENCODING = 'UTF8'`，SQL 文件保存为 UTF-8。
- 端口被占用：修改安装参数并保持后续连接参数一致。
- `.env` 已忽略但不会随 Git 提交；如果直接压缩整个目录分享，需先删除 `.env`。

## 7. v2 环境变量

`.env` 除原有配置外，还需要以下治理服务配置：

| 变量 | 说明 |
| --- | --- |
| `MOCK_PG_RO_PASSWORD` | `shop_ro` 密码 |
| `EMBEDDING_PG_DB` | 语义库，默认 `embedding_store` |
| `EMBEDDING_PG_USER` | 语义库角色，默认 `embed_app` |
| `EMBEDDING_PG_PASSWORD` | `embed_app` 密码 |
| `MEMORY_PG_DB` | 记忆库，默认 `agent_memory` |
| `MEMORY_PG_USER` | 记忆库角色，默认 `memory_app` |
| `MEMORY_PG_PASSWORD` | `memory_app` 密码 |
| `OP_LOG_DB` | 日志库，默认 `op_log` |
| `OP_LOG_USER` | 日志库角色，默认 `log_app` |
| `OP_LOG_PASSWORD` | `log_app` 密码 |
| `DASHSCOPE_API_KEY` | DashScope API Key |
| `QWEN_MODEL` | 默认 `qwen-turbo` |
| `EMBEDDING_MODEL` | 默认 `text-embedding-v3` |
| `EMBEDDING_DIMENSION` | 默认 `1024` |
| `APP_API_KEY` | FastAPI 访问密钥 |
| `GOVERNED_SQL_TIMEOUT_MS` | 默认 `3000` |
| `GOVERNED_SQL_MAX_ROWS` | 默认 `100` |
| `SEMANTIC_TABLE_LIMIT` | 语义检索表数量 |
| `SEMANTIC_COLUMN_LIMIT` | 语义检索字段数量 |
| `SEMANTIC_METRIC_LIMIT` | 语义检索指标数量 |
| `SEMANTIC_EXAMPLE_LIMIT` | 语义检索 SQL 示例数量 |
| `MEMORY_MESSAGE_LIMIT` | 会话上下文消息数量 |

所有治理服务必要配置缺失时直接启动失败，不使用默认密码或降级连接。

## 8. v2 初始化与启动

`init_all.ps1` 的执行顺序新增治理对象：

1. 执行 `00_bootstrap.sql` 创建基础角色和四库。
2. 执行 `05_shop_ro.sql` 创建只读角色。
3. 初始化 `shop_dw` 业务表、基础与扩展 mock 数据后，执行 `63_seed_refunds.sql` 补充 2026 年以来截至今日且不晚于今日的退款场景，再执行 `60_shop_dw_governance.sql`。
4. 初始化 `embedding_store` 基础表后执行 `61_embedding_governance.sql`。
5. 初始化 `op_log` 审计表后执行 `62_op_log_eval.sql`。
6. 执行语义向量同步。

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\init_all.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\sync_governance_semantic.ps1
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\start_governed_api.ps1
```

Docker 启动：

```powershell
docker compose up --build
```

Docker 初始化顺序：

1. `db` 通过 healthcheck 后执行 `docker/db/init/01_init.sh`，创建四库、角色、业务数据、治理元数据、记忆、审计与评测表。
2. `semantic-sync` 连接容器内 `db:5432`，调用 DashScope Embedding 生成治理语义向量，并校验向量完整。
3. `api` 等待 `semantic-sync` 成功退出后启动；任一环节失败都不静默降级。

数据库宿主机端口映射为 `5433:5432`。容器内服务仍连接 `db:5432`，宿主机工具如需访问 Docker 数据库应使用 `localhost:5433`。
