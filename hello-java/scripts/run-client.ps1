# Run Client - Java Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080/audio",
    [string]$InputFile = "..\audio\input\hello.mp3"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Set JAVA_HOME for Windows
if ($IsWindows -or ($env:OS -like '*Windows*')) {
    $CustomJdkPath = "D:\zoo\jdk-25.0.2"
    if (Test-Path $CustomJdkPath) {
        $env:JAVA_HOME = $CustomJdkPath
        $env:Path = "$CustomJdkPath\bin;$env:Path"
    }
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$ClientJar = "audio-stream-client\target\audio-stream-client-1.0.0.jar"

if (-not (Test-Path $ClientJar)) {
    Write-Host "Client JAR not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-client.ps1"
}

Write-Host "Starting Java Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

java --enable-preview -jar $ClientJar --input $InputFile
