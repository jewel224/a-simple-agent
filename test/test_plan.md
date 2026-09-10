# 测试计划

## 1. 测试目标

验证本地 PostgreSQL 18.6 学习数据库的环境、隔离、表结构、业务数据、向量检索、Agent 记忆和操作日志都符合设计。

## 2. 执行前提

- PostgreSQL 18.6 已安装并启动。
- pgvector 0.8.6 已复制到 PostgreSQL 扩展目录。
- `spec/scripts/init_all.ps1` 已成功执行。

## 3. 测试内容

| 文件 | 验证内容 |
| --- | --- |
| `sql/01_environment.sql` | 服务版本、4 个 database、4 个角色 |
| `sql/02_isolation.sql` | 四个角色只能连接自己的 database |
| `sql/03_shop_dw_structure.sql` | `shop_dw` 16 张表与主要约束 |
| `sql/04_shop_dw_business.sql` | 扩展 mock 数据规模、多地址/共享地址/共享手机号、类目订单量关系、大促、区域分布、物流状态同步 |
| `sql/05_embedding_store.sql` | 文档分块向量、cosine 查询 |
| `sql/06_agent_memory.sql` | 会话消息记忆、记忆关联 |
| `sql/07_operation_log.sql` | 日志插入、禁止 UPDATE/DELETE |

`run_all.ps1` 另外通过 psql 检查：

- `embedding_store`、`agent_memory` 中存在 `vector` 扩展。

业务库初始化后包含约 2.2 万订单规模：106 个地区、213 个用户、20 个商家、25 个类目、44 个商品、22307 个订单、22309 条订单明细、17809 条支付、14488 个物流运单、28977 条物流状态流水和 22310 条 App 事件。

扩展 mock 数据必须满足以下场景：

- 用户 1 有 3 个以上订单量差异明显的收件地址。
- 家庭共享地址由 2-4 个用户共同使用；公司共享地址由 20-200 个用户共同使用，但公司用户不共用手机号。
- 存在 10 个手机号各由 2 人共用，以及 5 个手机号各由 3 人共用。
- 商家总数不少于 20 个，且一个商家只经营一个大类。
- 女士相关订单量 > 婴童类 > 男士 > 家具家电。
- 618、双11、双12、双旦期间的订单量显著高于日常。
- 订单覆盖全国 31 个省份/自治区/直辖市，江浙沪订单占比偏高。

## 4. 运行方式

```powershell
powershell -ExecutionPolicy Bypass -File .\test\scripts\run_all.ps1
```

脚本优先读取项目根目录 `.env` 中的 `MOCK_PG_SUPER_PASSWORD` 与 `MOCK_PG_APP_PASSWORD`；若未创建 `.env`，也可以先设置同名环境变量再执行。

所有 SQL 文件在 `psql -v ON_ERROR_STOP=1` 下执行，任一测试失败立即返回非零退出码。
