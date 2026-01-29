# Build Client - C# Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building C# Client..." -ForegroundColor Cyan

dotnet build -c Release

Write-Host "Client build complete!" -ForegroundColor Green
