#!/bin/bash

# Run Client - Rust Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CLIENT_BIN="target/release/audio_stream_client"

if [ ! -f "$CLIENT_BIN" ]; then
    echo "Binary not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

echo "Starting Rust Client..."

exec "$CLIENT_BIN" "$@"
