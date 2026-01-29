#!/bin/bash

# Run Server - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting Kotlin Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

if [ ! -f "server/build/install/server/bin/server" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

server/build/install/server/bin/server "$PORT" "$PATH_ENDPOINT"
