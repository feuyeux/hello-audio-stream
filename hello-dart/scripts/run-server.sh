#!/bin/bash

# Run Server - Dart Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_BIN="audio_stream_server"

if [ ! -f "$SERVER_BIN" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

echo "Starting Dart Server..."
echo "Press Ctrl+C to stop"
echo ""

exec "./$SERVER_BIN" "$@"
