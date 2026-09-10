# 下载 PostgreSQL 与 pgvector 安装依赖

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$downloadDir = Join-Path $repoRoot 'downloads'
$postgresExe = Join-Path $downloadDir 'postgresql-18.6-3-windows-x64.exe'
$pgvectorZip = Join-Path $downloadDir 'vector.v0.8.6-pg18.zip'

New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$postgresUrl = 'https://get.enterprisedb.com/postgresql/postgresql-18.6-3-windows-x64.exe'
$pgvectorUrl = 'https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.6_18/vector.v0.8.6-pg18.zip'

if (Test-Path $postgresExe) {
    Write-Host 'PostgreSQL installer already exists, skip download.'
} else {
    Write-Host 'Downloading PostgreSQL 18.6 installer, about 375 MB.'
    Invoke-WebRequest -Uri $postgresUrl -OutFile $postgresExe
}

if (Test-Path $pgvectorZip) {
    Write-Host 'pgvector package already exists, skip download.'
} else {
    Write-Host 'Downloading pgvector 0.8.6 for PostgreSQL 18.'
    Invoke-WebRequest -Uri $pgvectorUrl -OutFile $pgvectorZip
}

Write-Host 'Downloaded files:'
Get-ChildItem $downloadDir | Select-Object Name, Length | Format-Table -AutoSize
