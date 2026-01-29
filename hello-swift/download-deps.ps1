# Download Swift dependencies to local lib directory

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibDir = Join-Path $ScriptDir "lib"

Write-Host "Creating lib directory..."
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null

# Download swift-argument-parser
$ArgParserDir = Join-Path $LibDir "swift-argument-parser"
if (-not (Test-Path $ArgParserDir)) {
    Write-Host "Downloading swift-argument-parser..."
    Set-Location $LibDir
    git clone https://github.com/apple/swift-argument-parser.git
    Set-Location swift-argument-parser
    git checkout 1.3.0
    Write-Host "swift-argument-parser downloaded successfully"
} else {
    Write-Host "swift-argument-parser already exists"
}

Write-Host "All dependencies downloaded successfully"
