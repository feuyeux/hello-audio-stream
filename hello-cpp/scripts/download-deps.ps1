# Download dependencies for Audio Stream Cache - C++ Implementation (Windows PowerShell)
# Usage: .\download-deps.ps1

$ErrorActionPreference = "Stop"

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Proxy settings
$HTTP_PROXY = "http://127.0.0.1:55497"
$SOCKS_PROXY = "socks5://127.0.0.1:50110"

function Write-Header {
    param([string]$Message)
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -NoNewline -ForegroundColor Blue
    Write-Host $Message
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] " -NoNewline -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
}

# Start
Write-Header "Downloading Dependencies"

# Set lib directory
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$LibDir = Join-Path $ScriptDir "lib"
Write-Info "Lib directory: $LibDir"

# Create lib directory if not exists
if (-not (Test-Path $LibDir)) {
    New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
    Write-Info "Created lib directory"
}

# Change to lib directory
Push-Location $LibDir

# Function to clone or update a repository with proxy fallback
function CloneOrUpdate {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Tag
    )

    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host "Processing: $Name" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    $DirPath = Join-Path $LibDir $Name

    if (Test-Path $DirPath) {
        Write-Info "$Name already exists, updating..."
        Push-Location $Name
        git fetch origin 2>&1 | Out-Null
        git checkout $Tag 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Info "Checkout failed, using reset instead..."
            git reset --hard $Tag 2>&1 | Out-Null
        }
        Pop-Location
        Write-Info "✓ $Name updated"
    } else {
        Write-Info "Cloning $name..."
        
        # Try without proxy first
        $result = git clone --depth 1 --branch $Tag --single-branch $Url $Name 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ $Name cloned (no proxy)"
        } else {
            Write-Info "Direct connection failed, trying HTTP proxy..."
            # Try with HTTP proxy
            $env:HTTP_PROXY = $HTTP_PROXY
            $result = git clone --depth 1 --branch $Tag --single-branch $Url $Name 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Info "✓ $Name cloned (HTTP proxy)"
            } else {
                Write-Info "HTTP proxy failed, trying SOCKS proxy..."
                # Try with SOCKS proxy
                $env:ALL_PROXY = $SOCKS_PROXY
                $result = git clone --depth 1 --branch $Tag --single-branch $Url $Name 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "✓ $Name cloned (SOCKS proxy)"
                } else {
                    Write-Error-Custom "All connection methods failed for $Name"
                    throw "Failed to clone $Name"
                }
            }
            # Clear proxy environment variables
            Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
        }
    }
}

try {
    # Check if git is available
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git is not installed or not available in PATH"
    }
    Write-Info "Git version: $gitVersion"

    # Download dependencies
    CloneOrUpdate "asio" "https://github.com/chriskohlhoff/asio.git" "asio-1-30-2"
    CloneOrUpdate "websocketpp" "https://github.com/zaphoyd/websocketpp.git" "0.8.2"
    CloneOrUpdate "spdlog" "https://github.com/gabime/spdlog.git" "v1.14.1"
    CloneOrUpdate "nlohmann_json" "https://github.com/nlohmann/json.git" "v3.11.3"
    CloneOrUpdate "googletest" "https://github.com/google/googletest.git" "v1.14.0"
    CloneOrUpdate "rapidcheck" "https://github.com/emil-e/rapidcheck.git" "master"

    Write-Host ""
    Write-Header "All Dependencies Downloaded Successfully!"

    Write-Host ""
    Write-Host "Dependencies location: $LibDir"
    Write-Host ""

    Write-Host "Directory structure:" -ForegroundColor Cyan
    Get-ChildItem -Directory | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Green
    }

} catch {
    Write-Error-Custom $_.Exception.Message
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

Write-Host ""
exit 0
