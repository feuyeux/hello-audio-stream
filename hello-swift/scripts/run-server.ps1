# Run Server - Swift Implementation (Windows PowerShell)
param(
    [int]$Port = 8080,
    [string]$PathEndpoint = "/audio"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ServerBin = ".build\release\audio_stream_server.exe"

if (-not (Test-Path $ServerBin)) {
    Write-Host "Server not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

Write-Host "Starting Swift Server on port $Port..." -ForegroundColor Green
Write-Host "Endpoint: $PathEndpoint" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

& $ServerBin --port $Port --path $PathEndpoint
