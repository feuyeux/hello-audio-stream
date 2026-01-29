# Build Client - Python Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Setting up Python Client..." -ForegroundColor Cyan

if (-not (Test-Path "venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

& .\venv\Scripts\Activate.ps1
Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install -q -e .

Write-Host "Client setup complete!" -ForegroundColor Green
