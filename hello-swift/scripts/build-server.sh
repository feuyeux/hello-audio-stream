#!/bin/bash

# Build Server - Swift Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Swift Audio Stream Server..."

# Build server
swift build --product audio_stream_server

echo "Build completed successfully!"
echo "Executable: .build/release/audio_stream_server"
