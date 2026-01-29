#!/bin/bash

# Run Client - C# Implementation (Unix/Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting C# Client..."

dotnet run --configuration Release --project src/audio_stream_client/audio_stream_client.csproj -- "$@"
