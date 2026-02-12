#!/bin/bash

# Run Client - C# Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting C# Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

APP_DLL="bin/Release/net9.0/hello_audio_stream.dll"
if [ ! -f "$APP_DLL" ]; then
    echo "Build output not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

if [ ! -f "$APP_DLL" ]; then
    echo "Error: $APP_DLL not found after build."
    exit 1
fi

dotnet "$APP_DLL" client --server "$SERVER_URI" --input "$INPUT_FILE"
