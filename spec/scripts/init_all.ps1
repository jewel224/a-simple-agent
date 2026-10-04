# 初始化角色、数据库、扩展、表结构、治理对象与种子数据

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

$roPassword = $env:MOCK_PG_RO_PASSWORD
if (-not $roPassword) {
    throw 'MOCK_PG_RO_PASSWORD is required.'
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

function Invoke-PsqlAsAdminWithVariables {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][hashtable]$Variables
    )
    $env:PGPASSWORD = $superPassword
    $arguments = @('-X', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-h', 'localhost', '-p', '5432', '-d', $Database)
    foreach ($key in $Variables.Keys) {
        $arguments += @('-v', "$key=$($Variables[$key])")
    }
    $arguments += @('-f', $File)
    & $psql @arguments
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

# 创建基础角色与数据库
Invoke-PsqlAsAdmin -Database 'postgres' -File (Join-Path $ddlDir '00_bootstrap.sql')

# 创建治理链路专用只读角色
Invoke-PsqlAsAdminWithVariables -Database 'postgres' -File (Join-Path $ddlDir '05_shop_ro.sql') -Variables @{
    ro_password = $roPassword
}

# 启用向量扩展
$env:PGPASSWORD = $superPassword
& $psql -X -v ON_ERROR_STOP=1 -U postgres -h localhost -p 5432 -d embedding_store -c 'CREATE EXTENSION IF NOT EXISTS vector;'
if ($LASTEXITCODE -ne 0) { throw 'failed to create vector extension in embedding_store' }
& $psql -X -v ON_ERROR_STOP=1 -U postgres -h localhost -p 5432 -d agent_memory -c 'CREATE EXTENSION IF NOT EXISTS vector;'
if ($LASTEXITCODE -ne 0) { throw 'failed to create vector extension in agent_memory' }

# shop_dw：业务表、种子数据、只读授权与脱敏视图
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '10_shop_dw.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '50_seed_shop_dw.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '55_seed_shop_dw_extended.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '63_seed_refunds.sql')
Invoke-PsqlAsApp -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $ddlDir '60_shop_dw_governance.sql')

# embedding_store：向量基础表、种子数据与治理语义层
Invoke-PsqlAsApp -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $ddlDir '20_embedding_store.sql')
Invoke-PsqlAsApp -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $ddlDir '51_seed_embedding.sql')
Invoke-PsqlAsApp -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $ddlDir '61_embedding_governance.sql')

# agent_memory
Invoke-PsqlAsApp -Role 'memory_app' -Database 'agent_memory' -File (Join-Path $ddlDir '30_agent_memory.sql')
Invoke-PsqlAsApp -Role 'memory_app' -Database 'agent_memory' -File (Join-Path $ddlDir '52_seed_agent_memory.sql')

# op_log：审计日志与评测结果表
Invoke-PsqlAsApp -Role 'log_app' -Database 'op_log' -File (Join-Path $ddlDir '40_operation_log.sql')
Invoke-PsqlAsApp -Role 'log_app' -Database 'op_log' -File (Join-Path $ddlDir '53_seed_operation_log.sql')
Invoke-PsqlAsApp -Role 'log_app' -Database 'op_log' -File (Join-Path $ddlDir '62_op_log_eval.sql')

Write-Host 'Database initialization completed.'
Write-Host 'Tables: shop_dw 16 business tables + masked view, embedding_store 3 base tables + governance tables, agent_memory 3, op_log audit + eval tables.'
Write-Host 'Next: python -m app.governance.sync_semantic'

# 环境变量不再包含密码，避免后续误用
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
