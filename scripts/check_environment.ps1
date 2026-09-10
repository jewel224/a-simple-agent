# 检查 a-simple-agent 本机环境

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$script:Failed = $false
$psql = Join-Path $env:ProgramFiles 'PostgreSQL\18\bin\psql.exe'

function Report-Check {
    param([bool]$Ok, [string]$Name, [string]$Detail, [bool]$WarningOnly = $false)
    if ($Ok) { Write-Host "[PASS] $Name" -ForegroundColor Green }
    elseif ($WarningOnly) { Write-Host "[WARN] $Name - $Detail" -ForegroundColor Yellow }
    else { Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red; $script:Failed = $true }
}

function Invoke-PsqlCheck {
    param([string]$Role, [string]$Database, [string]$Sql)
    $env:PGPASSWORD = $env:MOCK_PG_PASSWORD
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $psql -X -t -A -w -U $Role -h $env:MOCK_PG_HOST -p $env:MOCK_PG_PORT -d $Database -c $Sql 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $oldPreference
    return @{ Ok = ($exitCode -eq 0); Output = (($output | Out-String).Trim()) }
}

Write-Host '=== a-simple-agent environment check ==='
Report-Check (Test-Path (Join-Path $repoRoot '.env')) '.env file' 'Copy .env.example to .env first'
Report-Check ([bool]$env:MOCK_PG_PASSWORD) 'MOCK_PG_PASSWORD' 'missing database password'
Report-Check ([bool]$env:MOCK_PG_SUPER_PASSWORD) 'MOCK_PG_SUPER_PASSWORD' 'needed by installation scripts' $true
Report-Check ([bool]$env:DASHSCOPE_API_KEY) 'DASHSCOPE_API_KEY' 'required before starting the Agent' $true

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { Report-Check $true 'Python' (& python --version 2>&1) }
else { Report-Check $false 'Python' 'python command not found' }

Report-Check (Test-Path (Join-Path $repoRoot 'requirements.txt')) 'requirements.txt' 'file missing'
Report-Check (Test-Path (Join-Path $repoRoot '.venv\Scripts\python.exe')) 'Python virtual environment' 'run python -m venv .venv' $true
Report-Check (Test-Path $psql) 'psql' "expected at $psql"

$service = Get-Service -Name 'postgresql-x64-18' -ErrorAction SilentlyContinue
if ($service) { Report-Check ($service.Status -eq 'Running') 'PostgreSQL service' "current status: $($service.Status)" }
else { Report-Check $false 'PostgreSQL service' 'postgresql-x64-18 not found' }

$port = if ($env:MOCK_PG_PORT) { [int]$env:MOCK_PG_PORT } else { 5432 }
try { $portOpen = Test-NetConnection -ComputerName localhost -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue }
catch { $portOpen = $false }
Report-Check $portOpen "PostgreSQL port $port" 'port is not reachable'

if ((Test-Path $psql) -and $env:MOCK_PG_PASSWORD) {
    $shopCheck = Invoke-PsqlCheck 'shop_app' 'shop_dw' "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
    Report-Check ($shopCheck.Ok -and $shopCheck.Output -eq '16') 'shop_dw has 16 tables' $shopCheck.Output

    $orderCheck = Invoke-PsqlCheck 'shop_app' 'shop_dw' 'SELECT count(*) FROM public.fact_order;'
    $orderCount = 0
    [void][int]::TryParse($orderCheck.Output, [ref]$orderCount)
    Report-Check ($orderCheck.Ok -and $orderCount -ge 20000) 'shop_dw mock order count' "got $($orderCheck.Output)"

    $embedCheck = Invoke-PsqlCheck 'embed_app' 'embedding_store' "SELECT count(*) FROM pg_extension WHERE extname='vector';"
    Report-Check ($embedCheck.Ok -and $embedCheck.Output -eq '1') 'embedding_store vector extension' $embedCheck.Output

    $memoryCheck = Invoke-PsqlCheck 'memory_app' 'agent_memory' "SELECT count(*) FROM pg_extension WHERE extname='vector';"
    Report-Check ($memoryCheck.Ok -and $memoryCheck.Output -eq '1') 'agent_memory vector extension' $memoryCheck.Output
}

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
if ($script:Failed) { Write-Host 'Environment check failed. See docs/troubleshooting.md.' -ForegroundColor Red; exit 1 }
Write-Host 'Environment check passed.' -ForegroundColor Green