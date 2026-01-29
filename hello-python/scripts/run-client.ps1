# Run Client - Python Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3",
    [string]$OutputFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not (Test-Path "venv")) {
    Write-Host "Virtual environment not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-client.ps1"
}

& .\venv\Scripts\Activate.ps1

Write-Host "Starting Python Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$args = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $args += @("--output", $OutputFile)
}

python -m audio_client.audio_client_application @args
