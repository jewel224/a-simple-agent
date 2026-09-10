# 隔离与权限设计

## 1. 数据库与角色

| Database | 用途 | 登录角色 | 权限边界 |
| --- | --- | --- | --- |
| `shop_dw` | 手机购物数仓 | `shop_app` | 只能连接 `shop_dw` |
| `embedding_store` | 文档向量 | `embed_app` | 只能连接 `embedding_store` |
| `agent_memory` | Agent 上下文记忆 | `memory_app` | 只能连接 `agent_memory` |
| `op_log` | 操作日志 | `log_app` | 只能连接 `op_log` |

每个角色同时是所属 database 的 owner，负责本库的 DDL、DML 与演示数据维护。

## 2. 隔离规则

1. PostgreSQL 本身不支持跨 database 查询，因此四个 database 之间没有数据交叉路径。
2. 初始化时撤销 `PUBLIC` 对四个 database 的默认 `CONNECT`，只给对应角色授权。
3. 每个库只承载单一业务语义，不创建跨库外键、FDW 或共享 schema。
4. `embedding_store` 与 `agent_memory` 都使用 `vector` 扩展，但表和对象完全独立。

## 3. 初始化授权

由 `postgres` 超级用户执行 `00_bootstrap.sql`：

```sql
CREATE DATABASE shop_dw OWNER shop_app;
REVOKE CONNECT ON DATABASE shop_dw FROM PUBLIC;
GRANT CONNECT ON DATABASE shop_dw TO shop_app;
```

四个 database 使用同样的规则，但只授权给各自角色。

## 4. 密码约定

- `postgres` 超级用户密码在安装 PostgreSQL 时设置，由 `MOCK_PG_SUPER_PASSWORD` 传入。
- `shop_app`、`embed_app`、`memory_app`、`log_app` 使用同一个本地开发密码，由 `MOCK_PG_APP_PASSWORD` 传入。
- 密码不写入 SQL、Markdown 或 PowerShell 源码；真实密码只保存在根目录 `.env`，该文件被 `.gitignore` 忽略。
- 本地学习环境仅监听 `localhost`；如需远程访问，应另行调整 `pg_hba.conf` 与防火墙。

## 5. 运维说明

- 日常学习使用各库对应角色连接，避免误操作其它库。
- 建表、修改表结构等维护操作由 `postgres` 或库 owner 执行。
- `op_log` 的日志表默认禁止 UPDATE/DELETE，需要清理历史数据时由 `postgres` 手动处理。
