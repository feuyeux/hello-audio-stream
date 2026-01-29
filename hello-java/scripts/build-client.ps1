# Build Client - Java Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Set JAVA_HOME for Windows
$env:JAVA_HOME = "d:/zoo/jdk-25"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Java Client..." -ForegroundColor Cyan

Set-Location audio-stream-client
mvn clean package -DskipTests
Set-Location ..

Write-Host "Client build complete!" -ForegroundColor Green
Write-Host "JAR: audio-stream-client\target\audio-stream-client-1.0-SNAPSHOT.jar" -ForegroundColor Green
