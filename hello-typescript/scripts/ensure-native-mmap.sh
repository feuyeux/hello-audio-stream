#!/bin/bash

# Ensure @fayzanx/mmap-io is built and loadable for the current Node ABI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PKG_DIR="node_modules/@fayzanx/mmap-io"

if [ ! -d "$PKG_DIR" ]; then
    echo "Installing dependencies for native mmap..."
    npm install
fi

if [ ! -f "$PKG_DIR/binding.gyp" ]; then
    echo "ERROR: $PKG_DIR/binding.gyp not found"
    exit 1
fi

# Node 25+ requires C++20 in addon compilation.
perl -0pi -e 's/-std=c\+\+17/-std=c++20/g' "$PKG_DIR/binding.gyp"

ABI="$(node -p 'process.versions.modules')"
PLATFORM="$(node -p 'process.platform')"
ARCH="$(node -p 'process.arch')"
TARGET_DIR="$PKG_DIR/build/binding/Release/node-v${ABI}-${PLATFORM}-${ARCH}"
TARGET_FILE="$TARGET_DIR/mmap_io.node"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Building @fayzanx/mmap-io for node-v${ABI}-${PLATFORM}-${ARCH}..."
    export CXXFLAGS="${CXXFLAGS:-} -std=c++20"
    npm rebuild @fayzanx/mmap-io
fi

if [ ! -f "$TARGET_FILE" ] && [ -f "$PKG_DIR/build/Release/mmap_io.node" ]; then
    mkdir -p "$TARGET_DIR"
    cp "$PKG_DIR/build/Release/mmap_io.node" "$TARGET_FILE"
fi

node -e "const mmap=require('@fayzanx/mmap-io'); if(!mmap||typeof mmap.map!=='function'||typeof mmap.sync!=='function'){throw new Error('Native mmap module invalid');} console.log('Native mmap ready:', process.version, 'abi=' + process.versions.modules);"
