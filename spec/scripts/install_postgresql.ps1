# 安装 PostgreSQL 18.6 并部署 pgvector

$ErrorActionPreference = 'Stop'

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
$isAdministrator = $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'env_loader.ps1')
Load-ProjectEnv -ProjectRoot $repoRoot

$downloadDir = Join-Path $repoRoot 'downloads'
$postgresExe = Join-Path $downloadDir 'postgresql-18.6-3-windows-x64.exe'
$pgvectorZip = Join-Path $downloadDir 'vector.v0.8.6-pg18.zip'
$pgInstallRoot = 'C:\Program Files\PostgreSQL\18'
$pgServiceName = 'postgresql-x64-18'
$pgPort = 5432

if (-not (Test-Path $postgresExe)) {
    throw 'PostgreSQL installer not found. Run download_dependencies.ps1 first.'
}

$superPassword = $env:MOCK_PG_SUPER_PASSWORD
if (-not $superPassword) {
    $superPassword = Read-Host 'Enter the local superuser password for role postgres'
}

if (-not (Get-Service -Name $pgServiceName -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing PostgreSQL 18.6 as Windows service.'
    $installArgs = @(
        '--mode', 'unattended',
        '--unattendedmodeui', 'none',
        '--serverport', "$pgPort",
        '--locale', 'C',
        '--superpassword', $superPassword,
        '--servicename', $pgServiceName
    )
    $process = Start-Process -FilePath $postgresExe -ArgumentList $installArgs -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "PostgreSQL installer exited with code $($process.ExitCode)."
    }
} else {
    Write-Host "PostgreSQL service $pgServiceName already exists, skip installation."
}

if (-not (Test-Path $pgvectorZip)) {
    throw 'pgvector package not found. Run download_dependencies.ps1 first.'
}

$extractDir = Join-Path $downloadDir 'pgvector_extract'
if (Test-Path $extractDir) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
Expand-Archive -LiteralPath $pgvectorZip -DestinationPath $extractDir -Force

$libDir = Join-Path $pgInstallRoot 'lib'
$extensionDir = Join-Path $pgInstallRoot 'share\extension'

$vectorDll = Get-ChildItem -Path $extractDir -Recurse -Filter 'vector.dll' | Select-Object -First 1
$vectorControl = Get-ChildItem -Path $extractDir -Recurse -Filter 'vector.control' | Select-Object -First 1
$vectorSqlFiles = Get-ChildItem -Path $extractDir -Recurse -Filter 'vector--*.sql'

if (-not $vectorDll -or -not $vectorControl -or -not $vectorSqlFiles) {
    throw 'pgvector package does not contain expected files.'
}

$sourceExtensionDir = Join-Path $extractDir 'share\extension'
$copyCommand = @"
Copy-Item -LiteralPath '$($vectorDll.FullName)' -Destination '$libDir\vector.dll' -Force
Copy-Item -LiteralPath '$($vectorControl.FullName)' -Destination '$extensionDir\vector.control' -Force
Get-ChildItem -LiteralPath '$sourceExtensionDir' -Filter 'vector--*.sql' | ForEach-Object {
    Copy-Item -LiteralPath `$_.FullName -Destination '$extensionDir' -Force
}
"@

if ($isAdministrator) {
    Invoke-Expression $copyCommand
} else {
    $encodedCopyCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($copyCommand)
    )
    $copyArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-EncodedCommand', $encodedCopyCommand
    )
    $copyProcess = Start-Process -FilePath powershell.exe -ArgumentList $copyArgs `
        -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    if ($copyProcess.ExitCode -ne 0) {
        throw "pgvector copy exited with code $($copyProcess.ExitCode)."
    }
}

Write-Host "PostgreSQL installed at $pgInstallRoot"
Write-Host "pgvector copied to $libDir and $extensionDir"
Write-Host 'Next step: run spec/scripts/init_all.ps1 to create the four databases.'
