#!/bin/bash

# Run Client - Dart Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CLIENT_BIN="audio_stream_client"

if [ ! -f "$CLIENT_BIN" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

echo "Starting Dart Client..."

exec "./$CLIENT_BIN" "$@"
