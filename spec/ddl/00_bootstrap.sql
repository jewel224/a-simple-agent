-- 初始化脚本：以 postgres 超级用户连接 postgres 数据库执行
-- 密码通过 psql 变量 app_password 传入，例如：
-- psql -U postgres -d postgres -v app_password="localdev" -f 00_bootstrap.sql

-- 创建四个应用角色
SELECT format('CREATE ROLE shop_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_app');
\gexec

SELECT format('ALTER ROLE shop_app LOGIN PASSWORD %L', :'app_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_app');
\gexec

SELECT format('CREATE ROLE embed_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'embed_app');
\gexec

SELECT format('ALTER ROLE embed_app LOGIN PASSWORD %L', :'app_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'embed_app');
\gexec

SELECT format('CREATE ROLE memory_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'memory_app');
\gexec

SELECT format('ALTER ROLE memory_app LOGIN PASSWORD %L', :'app_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'memory_app');
\gexec

SELECT format('CREATE ROLE log_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'log_app');
\gexec

SELECT format('ALTER ROLE log_app LOGIN PASSWORD %L', :'app_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'log_app');
\gexec

-- 创建四个独立 database
SELECT 'CREATE DATABASE shop_dw OWNER shop_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'shop_dw');
\gexec

SELECT 'CREATE DATABASE embedding_store OWNER embed_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'embedding_store');
\gexec

SELECT 'CREATE DATABASE agent_memory OWNER memory_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'agent_memory');
\gexec

SELECT 'CREATE DATABASE op_log OWNER log_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'op_log');
\gexec

-- 只允许对应角色连接自己的 database
REVOKE CONNECT ON DATABASE shop_dw FROM PUBLIC;
GRANT CONNECT ON DATABASE shop_dw TO shop_app;

REVOKE CONNECT ON DATABASE embedding_store FROM PUBLIC;
GRANT CONNECT ON DATABASE embedding_store TO embed_app;

REVOKE CONNECT ON DATABASE agent_memory FROM PUBLIC;
GRANT CONNECT ON DATABASE agent_memory TO memory_app;

REVOKE CONNECT ON DATABASE op_log FROM PUBLIC;
GRANT CONNECT ON DATABASE op_log TO log_app;
