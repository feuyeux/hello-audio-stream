# Build Server - Go Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Go Server..." -ForegroundColor Cyan

# Create bin directory
New-Item -ItemType Directory -Force -Path bin

go build -o bin/server.exe ./cmd/server

Write-Host "Server build complete!" -ForegroundColor Green
Write-Host "Binary: bin/server.exe" -ForegroundColor Green
