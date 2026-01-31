#!/bin/bash

# Build Server - Java Implementation (Unix/Linux/macOS)

set -e

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JAVA_HOME="/opt/homebrew/opt/java/libexec/openjdk.jdk/Contents/Home"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Java Audio Stream Server..."

cd audio-stream-server

# Build with Maven
mvn clean package -DskipTests

echo "Build completed successfully!"
echo "JAR: audio-stream-server/target/audio-stream-server.jar"
