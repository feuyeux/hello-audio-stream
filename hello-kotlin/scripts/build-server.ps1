# Build Server - Kotlin Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Kotlin Server..." -ForegroundColor Cyan

gradle build -x test

Write-Host "Server build complete!" -ForegroundColor Green
