# Run Server - PHP Implementation (Windows PowerShell)
param(
    [int]$Port = 8080
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "vendor")) {
    Write-Host "Dependencies not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

Write-Host "Starting PHP Server on port $Port..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

php audio_stream_server.php --port $Port
