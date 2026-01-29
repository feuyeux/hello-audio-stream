#!/bin/bash

# Run Client - C++ Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}
OUTPUT_FILE=${3:-}

CLIENT_BIN="build/bin/audio_stream_client"

if [ ! -f "$CLIENT_BIN" ]; then
    echo "Client not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

echo "Starting C++ Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

ARGS=("--server" "$SERVER_URI" "--input" "$INPUT_FILE")

if [ -n "$OUTPUT_FILE" ]; then
    ARGS+=("--output" "$OUTPUT_FILE")
fi

exec "$CLIENT_BIN" "${ARGS[@]}"
