# Run Client - PHP Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3",
    [string]$OutputFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# Convert relative input file path to absolute path
$InputFile = Join-Path -Path $ProjectRoot -ChildPath $InputFile -Resolve

if (-not (Test-Path "vendor")) {
    Write-Host "Dependencies not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-client.ps1"
}

Write-Host "Starting PHP Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$clientArgs = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $clientArgs += @("--output", $OutputFile)
}

php audio_stream_client.php @clientArgs
