#!/bin/bash

# Run Client - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting Kotlin Client..."

if [ ! -f "client/build/install/client/bin/client" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

client/build/install/client/bin/client "$@"
