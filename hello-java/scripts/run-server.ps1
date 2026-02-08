# Run Server - Java Implementation (Windows PowerShell)
param(
    [int]$Port = 8080,
    [string]$PathEndpoint = "/audio"
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

$ServerJar = "audio-stream-server\target\audio-stream-server-1.0.0.jar"

if (-not (Test-Path $ServerJar)) {
    Write-Host "Server JAR not found. Building..." -ForegroundColor Yellow
    & "$PSScriptRoot\build-server.ps1"
}

Write-Host "Starting Java Server on port $Port..." -ForegroundColor Green
Write-Host "Endpoint: $PathEndpoint" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

java --enable-preview -jar $ServerJar --port $Port --path $PathEndpoint
