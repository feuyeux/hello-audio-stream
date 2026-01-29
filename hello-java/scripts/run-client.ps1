# Run Client - Java Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3",
    [string]$OutputFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ClientJar = "audio-stream-client\target\audio-stream-client-1.0-SNAPSHOT.jar"

if (-not (Test-Path $ClientJar)) {
    Write-Host "Client JAR not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-client.ps1"
}

Write-Host "Starting Java Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$args = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $args += @("--output", $OutputFile)
}

java -jar $ClientJar @args
