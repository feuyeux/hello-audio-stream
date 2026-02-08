# Run Server - Swift Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# Set Swift Paths
$SwiftPath = "D:\zoo\swift6.2.3\Toolchains\6.2.3+Asserts\usr\bin"
# Note: Runtime path might be different or needed in PATH
$RuntimePath = "D:\zoo\swift6.2.3\Runtimes\6.2.3\usr\bin"

if (-not (Test-Path $SwiftPath)) {
    Write-Host "Error: Swift 6.2.3 Toolchain not found at $SwiftPath" -ForegroundColor Red
    exit 1
}

# Add Swift to PATH
$env:Path = "$SwiftPath;$RuntimePath;$env:Path"

# Run Server
$ServerExe = ".build\release\audio_stream_server.exe"

if (-not (Test-Path $ServerExe)) {
    Write-Host "Server executable not found at $ServerExe. Please run build-server.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Swift Audio Stream Server..." -ForegroundColor Green
& $ServerExe --port 8080 --path /audio
