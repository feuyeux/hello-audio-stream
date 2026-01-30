#!/bin/bash

# Run Client - Swift Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Configure Swift path based on OS
if [[ "$(uname)" == "Linux" ]]; then
    export PATH="/home/hanl5/zoo/swift-6.2.3/usr/bin:$PATH"
fi

CLIENT_BIN=".build/release/audio_stream_client"

if [ ! -f "$CLIENT_BIN" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

echo "Starting Swift Client..."

exec "$CLIENT_BIN" "$@"
