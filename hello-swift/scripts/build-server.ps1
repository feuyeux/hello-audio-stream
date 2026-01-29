# Build Server - Swift Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Swift Server..." -ForegroundColor Cyan

swift build -c release

Write-Host "Server build complete!" -ForegroundColor Green
Write-Host "Binary: .build\release\audio_stream_server.exe" -ForegroundColor Green
