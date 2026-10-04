# 重置 shop_dw 的 mock 数据

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$psql = Join-Path $env:ProgramFiles 'PostgreSQL\18\bin\psql.exe'
if (-not (Test-Path $psql)) {
    throw "未找到 psql：$psql"
}
if (-not $env:MOCK_PG_PASSWORD) {
    throw '缺少 MOCK_PG_PASSWORD，请在项目根目录 .env 中配置。'
}

$env:PGCLIENTENCODING = 'UTF8'
$env:PGPASSWORD = $env:MOCK_PG_PASSWORD
$baseSeed = Join-Path $repoRoot 'spec\ddl\50_seed_shop_dw.sql'
$extendedSeed = Join-Path $repoRoot 'spec\ddl\55_seed_shop_dw_extended.sql'
$refundSeed = Join-Path $repoRoot 'spec\ddl\63_seed_refunds.sql'

Write-Host 'Resetting shop_dw mock data...'
& $psql -X -v ON_ERROR_STOP=1 -w -U $env:MOCK_PG_USER -h $env:MOCK_PG_HOST -p $env:MOCK_PG_PORT -d $env:MOCK_PG_DB -f $baseSeed
if ($LASTEXITCODE -ne 0) { throw '基础 mock 数据重置失败。' }

& $psql -X -v ON_ERROR_STOP=1 -w -U $env:MOCK_PG_USER -h $env:MOCK_PG_HOST -p $env:MOCK_PG_PORT -d $env:MOCK_PG_DB -f $extendedSeed
if ($LASTEXITCODE -ne 0) { throw '扩展 mock 数据重置失败。' }

& $psql -X -v ON_ERROR_STOP=1 -w -U $env:MOCK_PG_USER -h $env:MOCK_PG_HOST -p $env:MOCK_PG_PORT -d $env:MOCK_PG_DB -f $refundSeed
if ($LASTEXITCODE -ne 0) { throw '退款 mock 数据重置失败。' }

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Write-Host 'shop_dw mock data reset completed.' -ForegroundColor Green