# Build Client - Go Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Go Client..." -ForegroundColor Cyan

# Create bin directory
New-Item -ItemType Directory -Force -Path bin

go build -o bin/client.exe ./cmd/client

Write-Host "Client build complete!" -ForegroundColor Green
Write-Host "Binary: bin/client.exe" -ForegroundColor Green
