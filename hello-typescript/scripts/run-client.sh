#!/bin/bash

# Run Client - TypeScript Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting TypeScript Client..."

if [ ! -d "node_modules" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

if [ ! -d "dist" ]; then
    echo "Dist not found. Building..."
    npm run build
fi

# Run client
node dist/client.js "$@"
