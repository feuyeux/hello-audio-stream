# Run Server - Kotlin Implementation (Windows PowerShell)
param(
    [int]$Port = 8080
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

Write-Host "Starting Kotlin Server on port $Port..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

gradle runServer --args="--port $Port" --console=plain
