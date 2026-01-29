#!/bin/bash

# Download Swift dependencies to local lib directory

set -e

export https_proxy=http://127.0.0.1:55497
export http_proxy=http://127.0.0.1:55497

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

echo "Creating lib directory..."
mkdir -p "$LIB_DIR"

# Download swift-argument-parser
if [ ! -d "$LIB_DIR/swift-argument-parser" ]; then
    echo "Downloading swift-argument-parser..."
    cd "$LIB_DIR"
    git clone https://github.com/apple/swift-argument-parser.git
    cd swift-argument-parser
    git checkout 1.3.0
    echo "swift-argument-parser downloaded successfully"
else
    echo "swift-argument-parser already exists"
fi

echo "All dependencies downloaded successfully"
