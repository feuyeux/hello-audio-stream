#!/bin/bash

# Build Client - Dart Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Dart audio stream client..."

# Get dependencies
echo "Getting dependencies..."
dart pub get

# Compile to native executable
echo "Compiling..."
dart compile exe bin/audio_stream_client.dart -o audio_stream_client

echo "Build completed successfully!"
echo "Executable: audio_stream_client"
