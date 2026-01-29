#!/bin/bash

# Build Client - C# Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building C# Audio Stream Client..."

# Restore dependencies
echo "Restoring dependencies..."
dotnet restore

# Build the project
echo "Building project..."
dotnet build --configuration Release --no-restore

echo "Build completed successfully!"
echo "Executable: bin/Release/net9.0/audio_stream_client"
