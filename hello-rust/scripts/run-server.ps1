# Run Server - Rust Implementation (Windows PowerShell)
param(
    [int]$Port = 8080,
    [string]$PathEndpoint = "/audio"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ServerBin = "target\release\audio_stream_server.exe"

if (-not (Test-Path $ServerBin)) {
    Write-Host "Server not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

if (-not (Test-Path "cache")) {
    New-Item -ItemType Directory -Path "cache" | Out-Null
}

Write-Host "Starting Rust Server on port $Port..." -ForegroundColor Green
Write-Host "Endpoint: $PathEndpoint" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

& $ServerBin --port $Port --path $PathEndpoint
