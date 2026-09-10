# 常见错误与修复

| 报错或现象 | 原因 | 修复 |
| --- | --- | --- |
| 禁止运行脚本 | PowerShell ExecutionPolicy 限制 | 使用 `powershell -ExecutionPolicy Bypass -File ...` |
| 缺少 `MOCK_PG_PASSWORD` | `.env` 未创建或未填写 | 复制 `.env.example` 为 `.env` 并填写 |
| 缺少 `DASHSCOPE_API_KEY` | 未配置模型密钥 | 在 `.env` 中填写 DashScope Key |
| `psql` 找不到 | PostgreSQL 未安装或不在 PATH | 使用完整路径 `C:\Program Files\PostgreSQL\18\bin\psql.exe` |
| 服务不存在 | PostgreSQL 未安装 | 运行 `spec/scripts/install_postgresql.ps1` |
| 服务已停止 | Windows 服务未启动 | 运行 `Start-Service postgresql-x64-18` |
| 端口 5432 被占用 | 已有 PostgreSQL 实例 | 停止旧服务或修改端口并同步 `.env` |
| 密码认证失败 | `.env` 密码与数据库不一致 | 重新初始化角色或填写正确密码 |
| `vector` 扩展不存在 | pgvector 未部署 | 重新运行 `install_postgresql.ps1` |
| `No module named dotenv` | Python 依赖未安装 | 执行 `pip install -r requirements.txt` |
| `to_markdown` 提示缺少 tabulate | 缺少 pandas 输出依赖 | 执行 `pip install tabulate` |
| WebUI 页面打不开 | 服务未启动、端口冲突或进程退出 | 查看终端错误，确认 DashScope Key 与依赖 |
| SQL 执行出错 | SQL 表名、字段名或权限错误 | 查看 Agent 返回的原始错误信息 |
| 中文乱码 | 客户端编码不一致 | 设置 `$env:PGCLIENTENCODING='UTF8'` |
| Git 中看到 `.env` | 忽略规则失效 | 执行 `git rm --cached .env`，保留本地文件 |

## 查看 PostgreSQL 是否运行

```powershell
Get-Service postgresql-x64-18
```

## 查看端口

```powershell
Test-NetConnection localhost -Port 5432
```

## 重新检查环境

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_environment.ps1
```