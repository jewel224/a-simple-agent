# 环境要求

## 1. 操作系统

- Windows 10 或 Windows 11，64 位。
- PowerShell 5.1 或更高版本。
- 安装 PostgreSQL 时需要管理员权限和 Windows UAC 确认。

## 2. 硬件与磁盘

| 项目 | 建议 |
| --- | --- |
| 内存 | 8 GB 以上 |
| 可用磁盘 | 3 GB 以上 |
| CPU | 64 位双核以上 |
| 网络 | 首次下载 PostgreSQL、pgvector、Python 依赖和调用 DashScope 时需要 |

## 3. Python

- 推荐 Python 3.13。
- 支持创建虚拟环境 `venv`。
- 不推荐直接使用系统 Python 安装依赖。
- Python 3.14 可能暂时缺少部分第三方库的预编译包。

验证：

```powershell
python --version
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

## 4. PostgreSQL 与 pgvector

| 组件 | 版本 |
| --- | --- |
| PostgreSQL | 18.6 |
| pgvector | 0.8.6 |
| 默认端口 | 5432 |
| 默认服务 | `postgresql-x64-18` |
| 安装目录 | `C:\Program Files\PostgreSQL\18` |

要求：

- 5432 端口没有被其它 PostgreSQL 实例占用。
- PostgreSQL Windows 服务可以正常运行。
- `embedding_store` 和 `agent_memory` 可以创建 `vector` 扩展。

## 5. DashScope

订单助手需要阿里云 DashScope API Key。

在项目根目录 `.env` 中配置：

```dotenv
DASHSCOPE_API_KEY=你的 DashScope API Key
```

没有 API Key 时，数据库可以正常使用，但订单助手无法调用大模型。

## 6. 数据库角色

Agent 默认使用：

| 配置 | 值 |
| --- | --- |
| Host | `localhost` |
| Port | `5432` |
| Database | `shop_dw` |
| User | `shop_app` |

密码通过 `.env` 中的 `MOCK_PG_PASSWORD` 提供。

## 7. 检查命令

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_environment.ps1
```

环境要求不满足时，先处理 `[FAIL]` 项，再启动订单助手。