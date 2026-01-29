#!/bin/bash

# Run Server - C# Implementation (Unix/Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting C# Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

dotnet run --configuration Release --project src/audio_stream_server/audio_stream_server.csproj -- "$PORT" "$PATH_ENDPOINT"
