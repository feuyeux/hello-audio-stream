#!/bin/bash

# Run Client - Java Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting Java Client..."

cd audio-stream-client

if [ ! -f "target/audio-stream-client.jar" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

java -jar target/audio-stream-client.jar "$@"
