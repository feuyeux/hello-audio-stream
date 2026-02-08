# Build Client - Rust Implementation (Windows PowerShell)
param(
    [ValidateSet("Release", "Debug")]
    [string]$BuildType = "Release"
)

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Rust Client ($BuildType)..." -ForegroundColor Cyan

try {
    if ($BuildType -eq "Release") {
        cargo build --release --bin client
        Write-Host "Client build complete!" -ForegroundColor Green
        Write-Host "Binary: target\release\client.exe" -ForegroundColor Green
    } else {
        cargo build --bin client
        Write-Host "Client build complete!" -ForegroundColor Green
        Write-Host "Binary: target\debug\client.exe" -ForegroundColor Green
    }
} catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    exit 1
}
