#!/bin/bash

# Run Client - Dart Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

CLIENT_BIN="audio_stream_client"

if [ ! -f "$CLIENT_BIN" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

echo "Starting Dart Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

exec "./$CLIENT_BIN" --server "$SERVER_URI" --input "$INPUT_FILE"
