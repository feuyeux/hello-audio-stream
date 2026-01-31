#!/bin/bash

# Run Server - TypeScript Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting TypeScript Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

if [ ! -d "node_modules" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

if [ ! -d "dist" ]; then
    echo "Dist not found. Building..."
    npm run build
fi

# Run server
node dist/server/main.js "$PORT" "$PATH_ENDPOINT"
