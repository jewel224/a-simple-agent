# 初始化角色、数据库、扩展、表结构与种子数据

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$pgBin = Join-Path $env:ProgramFiles 'PostgreSQL\18\bin'
$psql = Join-Path $pgBin 'psql.exe'

if (-not (Test-Path $psql)) {
    throw "psql not found at $psql. Install PostgreSQL first."
}

$superPassword = $env:MOCK_PG_SUPER_PASSWORD
if (-not $superPassword) {
    $superPassword = Read-Host 'Enter the local superuser password for role postgres'
}

$appPassword = $env:MOCK_PG_APP_PASSWORD
if (-not $appPassword) {
    $appPassword = Read-Host 'Enter the shared local password for shop_app/embed_app/memory_app/log_app'
}

$env:PGCLIENTENCODING = 'UTF8'
$ddlDir = Join-Path $PSScriptRoot '..\ddl'

function Invoke-PsqlAsAdmin {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$File
    )
    $env:PGPASSWORD = $superPassword
    & $psql -X -v ON_ERROR_STOP=1 -v "app_password=$appPassword" -U postgres -h localhost -p 5432 -d $Database -f $File
    if ($LASTEXITCODE -ne 0) { throw "psql failed for $File" }
}

function Invoke-PsqlAsApp {
    param(
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$File
    )
    $env:PGPASSWORD = $appPassword
    & $psql -X -v ON_ERROR_STOP=1 -U $Role -h localhost -p 5432 -d $Database -f $File
    if ($LASTEXITCODE -ne 0) { throw "psql failed for $File" }
}

# 创建角色与数据库
Invoke-PsqlAsAdmin -Database 'postgres' -File (Join-Path $ddlDir '00_bootstrap.sql')

# 启用向量扩展
$env:PGPASSWORD = $superPassword
& $psql -X -v ON_ERROR_STOP=1 -U postgres -h localhost -p 5432 -d embedding_store -c 'CREATE EXTENSION IF NOT EXISTS vector;'
if ($LASTEXITCODE -ne 0) { throw 'failed to create vector extension in embedding_store' }
& $psql -X -v ON_ERROR_STOP=1 -U postgres -h localhost -p 5432 -d agent_memory -c 'CREATE EXTENSION IF NOT EXISTS vector;'
if ($LASTEXITCODE -ne 0) { throw 'failed to create vector extension in agent_memory' }

# shop_dw
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '10_shop_dw.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '50_seed_shop_dw.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '55_seed_shop_dw_extended.sql')

# embedding_store
Invoke-PsqlAsApp -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $ddlDir '20_embedding_store.sql')
Invoke-PsqlAsApp -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $ddlDir '51_seed_embedding.sql')

# agent_memory
Invoke-PsqlAsApp -Role 'memory_app' -Database 'agent_memory' -File (Join-Path $ddlDir '30_agent_memory.sql')
Invoke-PsqlAsApp -Role 'memory_app' -Database 'agent_memory' -File (Join-Path $ddlDir '52_seed_agent_memory.sql')

# op_log
Invoke-PsqlAsApp -Role 'log_app' -Database 'op_log' -File (Join-Path $ddlDir '40_operation_log.sql')
Invoke-PsqlAsApp -Role 'log_app' -Database 'op_log' -File (Join-Path $ddlDir '53_seed_operation_log.sql')

Write-Host 'Database initialization completed.'
Write-Host 'Tables: shop_dw 16, embedding_store 3, agent_memory 3, op_log 1.'

# 环境变量不再包含密码，避免后续误用
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
