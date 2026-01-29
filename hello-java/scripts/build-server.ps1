# Build Server - Java Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Set JAVA_HOME for Windows
$env:JAVA_HOME = "d:/zoo/jdk-25"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Java Server..." -ForegroundColor Cyan

Set-Location audio-stream-server
mvn clean package -DskipTests
Set-Location ..

Write-Host "Server build complete!" -ForegroundColor Green
Write-Host "JAR: audio-stream-server\target\audio-stream-server-1.0-SNAPSHOT.jar" -ForegroundColor Green
