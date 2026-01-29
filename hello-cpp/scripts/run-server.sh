#!/bin/bash

# Run Server - C++ Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

SERVER_BIN="build/bin/audio_stream_server"

if [ ! -f "$SERVER_BIN" ]; then
    echo "Server not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

echo "Starting C++ Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

exec "$SERVER_BIN" "$PORT" "$PATH_ENDPOINT"
