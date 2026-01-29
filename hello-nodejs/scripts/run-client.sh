#!/bin/bash

# Run Client - Node.js Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting Node.js Client..."

if [ ! -d "node_modules" ]; then
    echo "Dependencies not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

# Run client
node src/client.js "$@"
