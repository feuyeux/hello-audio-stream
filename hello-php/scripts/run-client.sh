#!/bin/bash

# Run Client - PHP Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting PHP Client..."

if [ ! -d "vendor" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

# Set default input file if not provided
if [[ "$@" != *"--input"* ]]; then
    DEFAULT_INPUT="../audio/input/hello.mp3"
    # Convert to absolute path
    if [[ -f "$DEFAULT_INPUT" ]]; then
        INPUT_ABSOLUTE="$(cd "$(dirname "$DEFAULT_INPUT")" && pwd)/$(basename "$DEFAULT_INPUT")"
        set -- "$@" "--input" "$INPUT_ABSOLUTE"
    fi
fi

# Run client
php audio_stream_client.php "$@"
