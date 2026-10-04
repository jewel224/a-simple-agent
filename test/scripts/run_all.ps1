# 统一执行 spec 与 test 验收测试

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\..\spec\scripts\env_loader.ps1')
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
$sqlDir = Join-Path $PSScriptRoot '..\sql'
$python = Join-Path $repoRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) {
    throw "Python virtual environment not found: $python"
}

# Python 单元测试：SQLGuard 请求级语义范围与工具结果隔离
Push-Location $repoRoot
try {
    & $python -X utf8 -m unittest discover -s (Join-Path $PSScriptRoot '..\python') -v
    if ($LASTEXITCODE -ne 0) {
        throw 'Python unit tests failed.'
    }
    Write-Host '[PASS] Python governance unit tests'
} finally {
    Pop-Location
}


function Invoke-TestSql {
    param(
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($Role -eq 'postgres') {
        $env:PGPASSWORD = $superPassword
    } elseif ($Role -eq 'shop_ro') {
        $env:PGPASSWORD = $roPassword
    } else {
        $env:PGPASSWORD = $appPassword
    }
    & $psql -X -v ON_ERROR_STOP=1 -w -U $Role -h localhost -p 5432 -d $Database -f $File
    if ($LASTEXITCODE -ne 0) {
        throw "Test failed: $Name"
    }
    Write-Host "[PASS] $Name"
}

Invoke-TestSql -Role 'postgres' -Database 'postgres' -File (Join-Path $sqlDir '01_environment.sql') -Name 'environment versions, databases, roles'

# 扩展检查
$env:PGPASSWORD = $superPassword
& $psql -X -v ON_ERROR_STOP=1 -w -U postgres -h localhost -p 5432 -d embedding_store -c "SELECT 1 / (SELECT count(*) FROM pg_extension WHERE extname='vector')::int;"
if ($LASTEXITCODE -ne 0) { throw 'vector extension missing in embedding_store' }
Write-Host '[PASS] vector extension in embedding_store'

& $psql -X -v ON_ERROR_STOP=1 -w -U postgres -h localhost -p 5432 -d agent_memory -c "SELECT 1 / (SELECT count(*) FROM pg_extension WHERE extname='vector')::int;"
if ($LASTEXITCODE -ne 0) { throw 'vector extension missing in agent_memory' }
Write-Host '[PASS] vector extension in agent_memory'

# 基础隔离与数据
Invoke-TestSql -Role 'postgres' -Database 'postgres' -File (Join-Path $sqlDir '02_isolation.sql') -Name 'role database isolation'
Invoke-TestSql -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $sqlDir '03_shop_dw_structure.sql') -Name 'shop_dw 16 table structure'
Invoke-TestSql -Role 'shop_app' -Database 'shop_dw' -File (Join-Path $sqlDir '04_shop_dw_business.sql') -Name 'shop_dw business rules and logistics sync'
Invoke-TestSql -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $sqlDir '05_embedding_store.sql') -Name 'embedding_store vector retrieval'
Invoke-TestSql -Role 'memory_app' -Database 'agent_memory' -File (Join-Path $sqlDir '06_agent_memory.sql') -Name 'agent_memory sessions messages memories'
Invoke-TestSql -Role 'log_app' -Database 'op_log' -File (Join-Path $sqlDir '07_operation_log.sql') -Name 'operation_log append only'

# v2 治理对象
Invoke-TestSql -Role 'shop_ro' -Database 'shop_dw' -File (Join-Path $sqlDir '08_governance.sql') -Name 'shop_ro permissions and masked view'
Invoke-TestSql -Role 'embed_app' -Database 'embedding_store' -File (Join-Path $sqlDir '09_governance_metadata.sql') -Name 'governance semantic metadata'
Invoke-TestSql -Role 'log_app' -Database 'op_log' -File (Join-Path $sqlDir '10_eval_tables.sql') -Name 'eval append-only tables'

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Write-Host 'All tests passed.'
