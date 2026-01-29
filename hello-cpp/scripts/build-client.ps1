# Build Client - C++ Implementation (Windows PowerShell)
param(
    [ValidateSet("Release", "Debug")]
    [string]$BuildType = "Release",
    [switch]$Clean
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "Building C++ Client ($BuildType)..." -ForegroundColor Cyan

$BuildDir = "build"
$CpuCores = $env:NUMBER_OF_PROCESSORS
if (-not $CpuCores) { $CpuCores = 4 }

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Path $BuildDir -Recurse -Force
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

Push-Location $BuildDir

try {
    Write-Host "Configuring CMake..." -ForegroundColor Yellow
    cmake .. -DCMAKE_BUILD_TYPE=$BuildType -DBUILD_CLIENT=ON -DBUILD_SERVER=OFF
    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed" }

    Write-Host "Building client..." -ForegroundColor Yellow
    cmake --build . --config $BuildType --target audio_stream_client --parallel $CpuCores
    if ($LASTEXITCODE -ne 0) { throw "Build failed" }

    Write-Host "Client build complete!" -ForegroundColor Green
    Write-Host "Binary: build\bin\$BuildType\audio_stream_client.exe" -ForegroundColor Green
} finally {
    Pop-Location
}
