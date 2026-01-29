#!/bin/bash

# Build Client - Java Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Java Audio Stream Client..."

cd audio-stream-client

# Build with Maven
mvn clean package -DskipTests

echo "Build completed successfully!"
echo "JAR: audio-stream-client/target/audio-stream-client.jar"
