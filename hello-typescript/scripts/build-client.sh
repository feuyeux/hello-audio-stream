#!/bin/bash

# Build Client - TypeScript Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building TypeScript Audio Stream Client..."

# Ensure native addons (mmap-io) are compiled with a modern C++ standard.
export CXXFLAGS="${CXXFLAGS:-} -std=c++20"

# Install dependencies
echo "Installing dependencies..."
npm install

# Ensure native mmap addon is built for current Node ABI.
bash "$SCRIPT_DIR/ensure-native-mmap.sh"

# Build TypeScript
echo "Building TypeScript..."
npm run build

echo "Build completed successfully!"
echo "Run with: node dist/client.js"
