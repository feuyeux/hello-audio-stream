# Run Client - Rust Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3",
    [string]$OutputFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ClientBin = "target\release\audio_stream_client.exe"

if (-not (Test-Path $ClientBin)) {
    Write-Host "Client not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-client.ps1"
}

Write-Host "Starting Rust Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$clientArgs = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $clientArgs += @("--output", $OutputFile)
}

& $ClientBin @clientArgs
