# 同步治理语义层元数据向量

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

if (-not $env:DASHSCOPE_API_KEY) {
    throw 'DASHSCOPE_API_KEY is required.'
}

$activateScript = Join-Path $repoRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path $activateScript)) {
    throw "Python virtual environment not found: $activateScript"
}
. $activateScript

python -m app.governance.sync_semantic
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
