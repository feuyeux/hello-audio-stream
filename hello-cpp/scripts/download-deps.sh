#!/bin/bash
# Download dependencies for Audio Stream Cache - C++ Implementation
# Usage: ./download-deps.sh

set -e  # Exit on error

echo "========================================="
echo "Downloading dependencies to lib directory"
echo "========================================="

# Create lib directory if not exists
LIB_DIR="$(dirname "$0")/lib"
mkdir -p "$LIB_DIR"
cd "$LIB_DIR"

# Proxy settings
HTTP_PROXY="http://127.0.0.1:55497"
SOCKS_PROXY="socks5://127.0.0.1:50110"

# Function to try git clone with proxy fallback
clone_with_proxy() {
    local name=$1
    local url=$2
    local tag=$3

    echo ""
    echo "----------------------------------------"
    echo "Processing: $name"
    echo "----------------------------------------"

    if [ -d "$name" ]; then
        echo "$name already exists, updating..."
        cd "$name"
        git fetch origin
        git checkout "$tag" || git reset --hard "$tag"
        cd ..
    else
        echo "Cloning $name..."
        
        # Try without proxy first
        if git clone --depth 1 --branch "$tag" --single-branch "$url" "$name" 2>/dev/null; then
            echo "✓ $name cloned (no proxy)"
        else
            echo "Direct connection failed, trying HTTP proxy..."
            # Try with HTTP proxy
            if git -c http.proxy="$HTTP_PROXY" clone --depth 1 --branch "$tag" --single-branch "$url" "$name" 2>/dev/null; then
                echo "✓ $name cloned (HTTP proxy)"
            else
                echo "HTTP proxy failed, trying SOCKS proxy..."
                # Try with SOCKS proxy
                if git -c http.proxy="$SOCKS_PROXY" clone --depth 1 --branch "$tag" --single-branch "$url" "$name" 2>/dev/null; then
                    echo "✓ $name cloned (SOCKS proxy)"
                else
                    echo "✗ All connection methods failed for $name"
                    return 1
                fi
            fi
        fi
    fi

    echo "✓ $name ready"
}

# Download dependencies
clone_with_proxy "asio" "https://github.com/chriskohlhoff/asio.git" "asio-1-30-2"
clone_with_proxy "websocketpp" "https://github.com/zaphoyd/websocketpp.git" "0.8.2"
clone_with_proxy "spdlog" "https://github.com/gabime/spdlog.git" "v1.14.1"
clone_with_proxy "nlohmann_json" "https://github.com/nlohmann/json.git" "v3.11.3"
clone_with_proxy "googletest" "https://github.com/google/googletest.git" "v1.14.0"
clone_with_proxy "rapidcheck" "https://github.com/emil-e/rapidcheck.git" "master"

echo ""
echo "========================================="
echo "All dependencies downloaded successfully!"
echo "========================================="
echo ""
echo "Dependencies location: $LIB_DIR"
echo ""
echo "Directory structure:"
ls -1
