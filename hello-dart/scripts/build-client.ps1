# Build Client - Dart Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Dart Client..." -ForegroundColor Cyan

dart pub get
dart compile exe lib/audio_stream_client.dart -o audio_stream_client.exe

Write-Host "Client build complete!" -ForegroundColor Green
Write-Host "Binary: audio_stream_client.exe" -ForegroundColor Green
