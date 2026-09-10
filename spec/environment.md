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
