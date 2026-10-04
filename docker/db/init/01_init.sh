#!/usr/bin/env bash
# 初始化 Docker 环境中的业务库、治理语义库、记忆库、日志库与评测库对象

set -euo pipefail

POSTGRES_USER="${POSTGRES_USER:-postgres}"
APP_PASSWORD="${MOCK_PG_APP_PASSWORD:?MOCK_PG_APP_PASSWORD is required}"
RO_PASSWORD="${MOCK_PG_RO_PASSWORD:?MOCK_PG_RO_PASSWORD is required}"
DDL_DIR="/opt/project/spec/ddl"

run_admin_sql() {
    local database="$1"
    local file="$2"
    shift 2
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -X -v ON_ERROR_STOP=1 -h localhost -U "${POSTGRES_USER}" -d "${database}" "$@" -f "${file}"
}

run_app_sql() {
    local role="$1"
    local database="$2"
    local file="$3"
    PGPASSWORD="${APP_PASSWORD}" psql -X -v ON_ERROR_STOP=1 -h localhost -U "${role}" -d "${database}" -f "${file}"
}

# 创建基础角色、数据库和治理只读角色
run_admin_sql postgres "${DDL_DIR}/00_bootstrap.sql" -v app_password="${APP_PASSWORD}"
run_admin_sql postgres "${DDL_DIR}/05_shop_ro.sql" -v ro_password="${RO_PASSWORD}"

# 启用 pgvector 扩展
PGPASSWORD="${POSTGRES_PASSWORD}" psql -X -v ON_ERROR_STOP=1 -h localhost -U "${POSTGRES_USER}" -d embedding_store -c 'CREATE EXTENSION IF NOT EXISTS vector;'
PGPASSWORD="${POSTGRES_PASSWORD}" psql -X -v ON_ERROR_STOP=1 -h localhost -U "${POSTGRES_USER}" -d agent_memory -c 'CREATE EXTENSION IF NOT EXISTS vector;'

# shop_dw
run_app_sql shop_app shop_dw "${DDL_DIR}/10_shop_dw.sql"
run_app_sql shop_app shop_dw "${DDL_DIR}/50_seed_shop_dw.sql"
run_app_sql shop_app shop_dw "${DDL_DIR}/55_seed_shop_dw_extended.sql"
run_app_sql shop_app shop_dw "${DDL_DIR}/63_seed_refunds.sql"
run_app_sql shop_app shop_dw "${DDL_DIR}/60_shop_dw_governance.sql"

# embedding_store
run_app_sql embed_app embedding_store "${DDL_DIR}/20_embedding_store.sql"
run_app_sql embed_app embedding_store "${DDL_DIR}/51_seed_embedding.sql"
run_app_sql embed_app embedding_store "${DDL_DIR}/61_embedding_governance.sql"

# agent_memory
run_app_sql memory_app agent_memory "${DDL_DIR}/30_agent_memory.sql"
run_app_sql memory_app agent_memory "${DDL_DIR}/52_seed_agent_memory.sql"

# op_log
run_app_sql log_app op_log "${DDL_DIR}/40_operation_log.sql"
run_app_sql log_app op_log "${DDL_DIR}/53_seed_operation_log.sql"
run_app_sql log_app op_log "${DDL_DIR}/62_op_log_eval.sql"

echo 'Docker database initialization completed.'
