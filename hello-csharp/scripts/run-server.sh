#!/bin/bash

# Run Server - C# Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting C# Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

APP_DLL="bin/Release/net9.0/hello_audio_stream.dll"
if [ ! -f "$APP_DLL" ]; then
    echo "Build output not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
fi

if [ ! -f "$APP_DLL" ]; then
    echo "Error: $APP_DLL not found after build."
    exit 1
fi

dotnet "$APP_DLL" server "$PORT" "$PATH_ENDPOINT"
