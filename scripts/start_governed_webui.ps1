# 启动旧版 qwen-agent WebUI（legacy 入口）

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$activateScript = Join-Path $repoRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path $activateScript)) {
    throw "Python virtual environment not found: $activateScript"
}
. $activateScript

python (Join-Path $repoRoot 'app\assistant_order_bot.py')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
