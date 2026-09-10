# Agent 应用设计

![Agent 流程图](../docs/agent_flow.png)

## 1. 应用目标

`app/assistant_order_bot.py` 是一个订单助手，使用 qwen-agent 调用大模型，将自然语言问题转换为 PostgreSQL SQL，查询 `shop_dw` 数仓后返回分析结果。

## 2. 数据流

```text
用户问题
  -> qwen-agent Assistant
  -> 生成 PostgreSQL SQL
  -> exc_sql 工具
  -> SQLAlchemy + psycopg2
  -> PostgreSQL shop_dw
  -> DataFrame
  -> Markdown 表格
  -> Agent 生成最终业务回答
```

## 3. 配置项

应用从项目根目录 `.env` 读取配置：

| 变量 | 说明 |
| --- | --- |
| `DASHSCOPE_API_KEY` | 阿里云 DashScope API Key |
| `MOCK_PG_HOST` | PostgreSQL 地址 |
| `MOCK_PG_PORT` | PostgreSQL 端口 |
| `MOCK_PG_USER` | 业务库角色，默认 `shop_app` |
| `MOCK_PG_PASSWORD` | 业务库角色密码 |
| `MOCK_PG_DB` | 业务库名，默认 `shop_dw` |

`.env` 已被 `.gitignore` 忽略，禁止提交到 Git。

## 4. Agent 组成

| 组件 | 说明 |
| --- | --- |
| `Assistant` | qwen-agent 对话代理，模型为 `qwen-turbo` |
| `system_prompt` | 提供 `shop_dw` 表结构、字段含义、业务背景和 SQL 示例 |
| `ExcSQLTool` | 注册名为 `exc_sql` 的函数工具，接收模型生成的 SQL |
| `WebUI` | qwen-agent 图形化 Web 界面 |

## 5. 启动方式

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r .\requirements.txt
python .\app\assistant_order_bot.py
```

## 6. 安全边界

- Agent 使用 `shop_app` 连接 `shop_dw`，不能访问 `embedding_store`、`agent_memory`、`op_log`。
- 数据库密码和 DashScope Key 只存放于本地 `.env`。
- SQL 工具属于学习型实现，公开分享时应尽量使用只读数据库角色。
- 当前只返回前 10 行结果，避免大批量数据直接进入模型上下文。