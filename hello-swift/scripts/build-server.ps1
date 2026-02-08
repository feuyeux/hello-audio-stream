# Build Server - Swift Implementation (Windows PowerShell)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# Set Swift Paths
$SwiftPath = "D:\zoo\swift6.2.3\Toolchains\6.2.3+Asserts\usr\bin"
$RuntimePath = "D:\zoo\swift6.2.3\Runtimes\6.2.3\usr\bin"
$SDKRoot = "D:\zoo\swift6.2.3\Platforms\6.2.3\Windows.platform\Developer\SDKs\Windows.sdk"

if (-not (Test-Path $SwiftPath)) {
    Write-Host "Error: Swift 6.2.3 Toolchain not found at $SwiftPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $RuntimePath)) {
    Write-Host "Error: Swift 6.2.3 Runtime not found at $RuntimePath" -ForegroundColor Red
    exit 1
}

Write-Host "Using Swift at: $SwiftPath" -ForegroundColor Green
$env:PATH = "$SwiftPath;$RuntimePath;$env:PATH"

if (Test-Path $SDKRoot) {
    Write-Host "Setting SDKROOT to: $SDKRoot" -ForegroundColor Green
    $env:SDKROOT = $SDKRoot
} else {
    Write-Host "Warning: SDKROOT not found at $SDKRoot" -ForegroundColor Yellow
}

Write-Host "Building Swift Server..." -ForegroundColor Cyan

swift build -c release --product audio_stream_server
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Server build complete!" -ForegroundColor Green
Write-Host "Binary: .build\release\audio_stream_server.exe" -ForegroundColor Green
