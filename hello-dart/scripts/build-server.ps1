# Build Server - Dart Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Dart Server..." -ForegroundColor Cyan

dart pub get
dart compile exe lib/server/audio_server_application.dart -o audio_stream_server.exe

Write-Host "Server build complete!" -ForegroundColor Green
Write-Host "Binary: audio_stream_server.exe" -ForegroundColor Green
