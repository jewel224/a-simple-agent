# 操作手册

## 1. 检查环境

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_environment.ps1
```

检查内容包括 Python、PostgreSQL 服务、端口、四个数据库、pgvector 和 `.env`。

## 2. 启动和停止 PostgreSQL

查看状态：

```powershell
Get-Service postgresql-x64-18
```

启动：

```powershell
Start-Service postgresql-x64-18
```

停止：

```powershell
Stop-Service postgresql-x64-18
```

启动和停止服务通常需要管理员权限。

## 3. 使用 pgAdmin 查看数据

启动 pgAdmin：

```powershell
& 'C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe'
```

注册服务器：

| 配置 | 值 |
| --- | --- |
| Host | `localhost` |
| Port | `5432` |
| Database | `shop_dw` |
| Username | `shop_app` |
| Password | `.env` 中的 `MOCK_PG_PASSWORD` |

展开 `shop_dw > Schemas > public > Tables`，右键表并选择 `View/Edit Data > All Rows`。

## 4. 使用 psql 查询

```powershell
$env:PGPASSWORD = (Get-Content .env | Where-Object { $_ -match '^MOCK_PG_PASSWORD=' }) -replace '^MOCK_PG_PASSWORD=', ''
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U shop_app -h localhost -d shop_dw
```

进入 psql 后可以直接执行 SQL。

## 5. 启动 Agent

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_agent.ps1
```

停止 Agent：在运行窗口按 `Ctrl+C`。

## 6. 重置 mock 数据

只重置 `shop_dw` 的 mock 数据，不修改数据库结构：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\reset_mock_data.ps1
```

完整重建角色、数据库和表：

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\init_all.ps1
```

## 7. 运行验收测试

```powershell
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
```

## 8. 查看操作日志

```powershell
$env:PGPASSWORD = (Get-Content .env | Where-Object { $_ -match '^MOCK_PG_PASSWORD=' }) -replace '^MOCK_PG_PASSWORD=', ''
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U log_app -h localhost -d op_log -c "SELECT occurred_at, source_system, action, result_status FROM audit.operation_log ORDER BY occurred_at DESC LIMIT 20;"
```

## 9. 分享前检查

```powershell
git check-ignore .env
```

如果输出 `.env`，说明忽略规则生效。不要上传：

- `.env`
- `downloads/`
- `.venv/`
- `__pycache__/`