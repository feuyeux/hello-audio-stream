# Build Server - C# Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building C# Server..." -ForegroundColor Cyan

dotnet build -c Release

Write-Host "Server build complete!" -ForegroundColor Green
