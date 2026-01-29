#!/bin/bash

# Build Server - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Kotlin Audio Stream Server..."

# Build with Gradle
./gradlew :server:build -x test

echo "Build completed successfully!"
echo "Executable: server/build/install/server/bin/server"
