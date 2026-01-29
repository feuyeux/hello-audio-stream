# Build Client - Kotlin Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Kotlin Client..." -ForegroundColor Cyan

gradle build -x test

Write-Host "Client build complete!" -ForegroundColor Green
