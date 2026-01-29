# Build Server - Rust Implementation (Windows PowerShell)
param(
    [ValidateSet("Release", "Debug")]
    [string]$BuildType = "Release"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building Rust Server ($BuildType)..." -ForegroundColor Cyan

try {
    if ($BuildType -eq "Release") {
        cargo build --release --bin audio_stream_server
        Write-Host "Server build complete!" -ForegroundColor Green
        Write-Host "Binary: target\release\audio_stream_server.exe" -ForegroundColor Green
    } else {
        cargo build --bin audio_stream_server
        Write-Host "Server build complete!" -ForegroundColor Green
        Write-Host "Binary: target\debug\audio_stream_server.exe" -ForegroundColor Green
    }
} catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    exit 1
}
