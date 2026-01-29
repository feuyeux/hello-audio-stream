#!/bin/bash

# Run Server - Java Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting Java Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

cd audio-stream-server

if [ ! -f "target/audio-stream-server.jar" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

java -jar target/audio-stream-server.jar "$PORT" "$PATH_ENDPOINT"
