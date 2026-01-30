# Run Client - Kotlin Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3",
    [string]$OutputFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Starting Kotlin Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$clientArgs = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $clientArgs += @("--output", $OutputFile)
}

$gradleArgs = $clientArgs -join ' '
gradle runClient --args="$gradleArgs" --console=plain
