# Build Client - Rust Implementation (Windows PowerShell)
param(
    [ValidateSet("Release", "Debug")]
    [string]$BuildType = "Release"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Rust Client ($BuildType)..." -ForegroundColor Cyan

try {
    if ($BuildType -eq "Release") {
        cargo build --release --bin audio_stream_client
        Write-Host "Client build complete!" -ForegroundColor Green
        Write-Host "Binary: target\release\audio_stream_client.exe" -ForegroundColor Green
    } else {
        cargo build --bin audio_stream_client
        Write-Host "Client build complete!" -ForegroundColor Green
        Write-Host "Binary: target\debug\audio_stream_client.exe" -ForegroundColor Green
    }
} catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    exit 1
}
