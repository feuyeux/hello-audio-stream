# Build Client - PHP Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Setting up PHP Client..." -ForegroundColor Cyan

if (-not (Test-Path "vendor")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    composer install
} else {
    Write-Host "Regenerating autoload files..." -ForegroundColor Yellow
    composer dump-autoload
}

Write-Host "Client setup complete!" -ForegroundColor Green
