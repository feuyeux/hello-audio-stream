#!/bin/bash

# Build Server - Dart Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Dart audio stream server..."

# Get dependencies
echo "Getting dependencies..."
dart pub get

# Compile to native executable
echo "Compiling..."
dart compile exe bin/audio_stream_server.dart -o audio_stream_server

echo "Build completed successfully!"
echo "Executable: audio_stream_server"
