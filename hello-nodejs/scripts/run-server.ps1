# Run Server - Node.js Implementation (Windows PowerShell)
param(
    [int]$Port = 8080,
    [string]$PathEndpoint = "/audio"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "node_modules")) {
    Write-Host "Dependencies not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

Write-Host "Starting Node.js Server on port $Port..." -ForegroundColor Green
Write-Host "Endpoint: $PathEndpoint" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

node src/server/main.js --port $Port --path $PathEndpoint
