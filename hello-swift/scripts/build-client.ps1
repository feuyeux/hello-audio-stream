# Build Client - Swift Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Swift Client..." -ForegroundColor Cyan

swift build -c release

Write-Host "Client build complete!" -ForegroundColor Green
Write-Host "Binary: .build\release\audio_stream_client.exe" -ForegroundColor Green
