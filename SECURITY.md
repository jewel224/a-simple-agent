# 安全说明

## 不要提交敏感信息

以下文件或内容不能上传到 Git：

- `.env`
- `MOCK_PG_SUPER_PASSWORD`
- `MOCK_PG_APP_PASSWORD`
- `MOCK_PG_PASSWORD`
- `DASHSCOPE_API_KEY`
- 真实生产数据库连接信息
- 个人手机号、地址和其它隐私数据

本项目 mock 数据中的地址和手机号均为演示数据。

## 数据库权限

- 订单助手使用 `shop_app` 连接 `shop_dw`。
- `shop_app` 不能连接 `embedding_store`、`agent_memory`、`op_log`。
- 公开部署时建议再创建一个只读数据库角色，避免 Agent 执行写操作。

## 报告问题

如果发现密钥泄露、SQL 注入或数据越权问题，请不要在公开 Issue 中粘贴真实密码。请先撤销泄露的 Key，再提交不包含敏感信息的说明。