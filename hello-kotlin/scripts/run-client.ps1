# Run Client - Kotlin Implementation (Windows PowerShell)
param(
    [string]$ServerUri = "ws://localhost:8080",
    [string]$InputFile = "..\audio\input\hello.opus",
    [string]$OutputFile
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

Write-Host "Starting Kotlin Client..." -ForegroundColor Green
Write-Host "Server: $ServerUri" -ForegroundColor Green
Write-Host "Input: $InputFile" -ForegroundColor Green

$clientArgs = @("--server", $ServerUri, "--input", $InputFile)
if ($OutputFile) {
    $clientArgs += @("--output", $OutputFile)
}

$gradleArgs = $clientArgs -join ' '
gradle runClient --args="$gradleArgs" --console=plain --stacktrace
