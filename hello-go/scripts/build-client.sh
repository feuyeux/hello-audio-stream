#!/bin/bash

# Build Client - Go Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Go audio stream client..."

# Download dependencies
go mod download

# Create bin directory
mkdir -p bin

# Build client
go build -o bin/client ./cmd/client

echo "Build completed successfully!"
echo "Executable: bin/client"
