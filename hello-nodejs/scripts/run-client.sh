#!/bin/bash

# Run Client - Node.js Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting Node.js Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

if [ ! -d "node_modules" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

# Run client
node src/index.js --server "$SERVER_URI" --input "$INPUT_FILE"
