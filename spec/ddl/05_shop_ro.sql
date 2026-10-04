-- 创建 v2 治理链路专用的只读角色
-- 执行角色：postgres，连接数据库：shop_dw
-- 说明：shop_ro 只用于 Agent 查询，不用于初始化和管理业务表

SELECT format('CREATE ROLE shop_ro LOGIN PASSWORD %L', :'ro_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_ro');
\gexec

SELECT format('ALTER ROLE shop_ro LOGIN PASSWORD %L', :'ro_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_ro');
\gexec

GRANT CONNECT ON DATABASE shop_dw TO shop_ro;
