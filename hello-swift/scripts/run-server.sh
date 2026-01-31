#!/bin/bash

# Run Server - Swift Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Configure Swift path based on OS
if [[ "$(uname)" == "Linux" ]]; then
    export PATH="/home/hanl5/zoo/swift-6.2.3/usr/bin:$PATH"
fi

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

SERVER_BIN=".build/release/audio_stream_server"

if [ ! -f "$SERVER_BIN" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

echo "Starting Swift Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

exec "$SERVER_BIN" "$PORT" "$PATH_ENDPOINT"
