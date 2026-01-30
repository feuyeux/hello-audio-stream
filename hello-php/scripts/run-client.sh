#!/bin/bash

# Run Client - PHP Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting PHP Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

if [ ! -d "vendor" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

# Run client
php audio_stream_client.php --server "$SERVER_URI" --input "$INPUT_FILE"
