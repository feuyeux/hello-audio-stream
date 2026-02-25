# Run Client - Swift Implementation (Windows PowerShell)

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

# Run Client
$ClientExe = ".build\release\audio_stream_client.exe"

if (-not (Test-Path $ClientExe)) {
    Write-Host "Client executable not found at $ClientExe. Please run build-client.ps1 first." -ForegroundColor Red
    exit 1
}

# Ensure test file exists
if (-not (Test-Path "test_input.txt")) {
    Set-Content -Path "test_input.txt" -Value "Hello Audio Stream Test Data"
}

Write-Host "Starting Swift Audio Stream Client..." -ForegroundColor Green
& $ClientExe --input ..\audio\input\hello.opus --server ws://localhost:8080
