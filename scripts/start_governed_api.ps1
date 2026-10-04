# 启动治理版 FastAPI 服务

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

if (-not $env:APP_API_KEY) {
    throw 'APP_API_KEY is required.'
}
if (-not $env:DASHSCOPE_API_KEY) {
    throw 'DASHSCOPE_API_KEY is required.'
}

$activateScript = Join-Path $repoRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path $activateScript)) {
    throw "Python virtual environment not found: $activateScript"
}
. $activateScript

python -m uvicorn app.governance.api:app --host 0.0.0.0 --port 8000
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
