# 新手快速开始

## 1. 这个项目能做什么

完成后，你会得到：

- 一套本机 PostgreSQL 18.6 数据库。
- 一个手机购物 App mock 数仓，约 2.2 万订单。
- 一个可以在浏览器中提问的订单助手。
- 向量库、Agent 记忆库和操作日志库。
- 一套可重复执行的测试和初始化脚本。

## 2. 开始前准备

完整环境要求见 `environment_requirements.md`。

必须准备：

- Windows 10/11 64 位。
- Python 3.13。
- 管理员权限，仅用于安装 PostgreSQL。
- 阿里云 DashScope API Key。
- 至少 3 GB 可用磁盘空间。

建议先关闭占用 5432 端口的其它 PostgreSQL 服务。

## 3. 配置 .env

在项目根目录执行：

```powershell
Copy-Item .env.example .env
```

编辑 `.env`：

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

`.env` 不能提交到 Git，也不能发给别人。

## 4. 安装 PostgreSQL 和项目数据库

```powershell
powershell -ExecutionPolicy Bypass -File .\spec\scripts\download_dependencies.ps1
powershell -ExecutionPolicy Bypass -File .\spec\scripts\install_postgresql.ps1
powershell -ExecutionPolicy Bypass -File .\spec\scripts\init_all.ps1
```

初始化完成后，预期能看到：

```text
Database initialization completed.
Tables: shop_dw 16, embedding_store 3, agent_memory 3, op_log 1.
```

## 5. 检查环境

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_environment.ps1
```

全部显示 `PASS` 后再继续。

## 6. 安装 Python 依赖

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt
```

推荐 Python 3.13。Python 3.14 可能暂时没有部分第三方库的预编译包。

## 7. 启动订单助手

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_agent.ps1
```

或者手动启动：

```powershell
.\.venv\Scripts\Activate.ps1
python .\app\assistant_order_bot.py
```

浏览器打开 qwen-agent 输出的本地地址。

## 8. 第一次提问

在 WebUI 中输入：

```text
当前一共有多少订单？
```

预期结果约为：

```text
22307
```

再尝试：

```text
女士相关商品和男士相关商品哪个订单更多？
```

预期结论：

```text
女士相关订单更多。
```

## 9. 成功后检查清单

- PostgreSQL 服务正在运行。
- `.env` 已填写，且没有被 Git 跟踪。
- 四个数据库都存在。
- `shop_dw` 有 16 张表。
- 订单数量约为 2.2 万。
- Python 依赖已安装。
- WebUI 能正常提问并返回结果。

## 10. 下一步阅读

- `docs/concept_map.md`：理解数仓和 Agent。
- `docs/demo.md`：照着示例问题体验。
- `docs/operations.md`：启停、查看和重置。
- `docs/troubleshooting.md`：遇到错误时查询。