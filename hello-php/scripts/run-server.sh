#!/bin/bash

# Run Server - PHP Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting PHP Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

if [ ! -d "vendor" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

# Verify PHP file exists
if [ ! -f "audio_stream_server.php" ]; then
    echo "Error: audio_stream_server.php not found in $PROJECT_ROOT"
    exit 1
fi

# Run server
php audio_stream_server.php --port "$PORT" --path "$PATH_ENDPOINT"
