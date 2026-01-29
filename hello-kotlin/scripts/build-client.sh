#!/bin/bash

# Build Client - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Kotlin Audio Stream Client..."

# Build with Gradle
./gradlew :client:build -x test

echo "Build completed successfully!"
echo "Executable: client/build/install/client/bin/client"
