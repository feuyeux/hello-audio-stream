# Build Client - Java Implementation (Windows PowerShell)

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

Write-Host "Building Java Client..." -ForegroundColor Cyan

Set-Location audio-stream-client
mvn clean package -DskipTests
Set-Location ..

Write-Host "Client build complete!" -ForegroundColor Green
Write-Host "JAR: audio-stream-client\target\audio-stream-client-1.0-SNAPSHOT.jar" -ForegroundColor Green
