#!/bin/bash

# Run Client - Java Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting Java Client..."

cd audio-stream-client

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../../audio/input/hello.mp3}

JAR_FILE=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
    JAR_FILE=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
fi

echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

java --enable-preview -jar "$JAR_FILE" --server "$SERVER_URI" --input "$INPUT_FILE"
