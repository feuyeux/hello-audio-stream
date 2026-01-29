#!/bin/bash

# Build Client - Node.js Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Node.js Audio Stream Client..."

# Install dependencies
echo "Installing dependencies..."
npm install

# Build TypeScript (if applicable)
if [ -f "tsconfig.json" ]; then
    echo "Building TypeScript..."
    npm run build
fi

echo "Build completed successfully!"
echo "Run with: node src/client.js"
