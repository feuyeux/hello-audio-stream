#!/bin/bash

# Run Client - C# Implementation (Unix/Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting C# Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

dotnet run --configuration Release --project AudioFileTransfer.csproj -- client --server "$SERVER_URI" --input "$INPUT_FILE"
