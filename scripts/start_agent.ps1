# 启动 a-simple-agent 订单助手

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
. (Join-Path $repoRoot 'spec\scripts\env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$python = Join-Path $repoRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) {
    throw 'Python 虚拟环境不存在。请先执行：python -m venv .venv，然后 pip install -r requirements.txt'
}

if (-not $env:DASHSCOPE_API_KEY) {
    throw '缺少 DASHSCOPE_API_KEY，请在项目根目录 .env 中配置。'
}

$bot = Join-Path $repoRoot 'app\assistant_order_bot.py'
Write-Host 'Starting a-simple-agent WebUI...'
& $python $bot