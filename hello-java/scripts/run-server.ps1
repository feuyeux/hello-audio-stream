# Run Server - Java Implementation (Windows PowerShell)
param(
    [int]$Port = 8080,
    [string]$PathEndpoint = "/audio"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ServerJar = "audio-stream-server\target\audio-stream-server-1.0.0.jar"

if (-not (Test-Path $ServerJar)) {
    Write-Host "Server JAR not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

Write-Host "Starting Java Server on port $Port..." -ForegroundColor Green
Write-Host "Endpoint: $PathEndpoint" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

java -jar $ServerJar --port $Port --path $PathEndpoint
