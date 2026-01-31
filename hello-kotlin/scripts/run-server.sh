#!/bin/bash

# Run Server - Kotlin Implementation (Unix/Linux/macOS)

set -e

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JAVA_HOME="/opt/homebrew/opt/java/libexec/openjdk.jdk/Contents/Home"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Ubuntu/Linux
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export GRADLE_HOME=/home/hanl5/zoo/gradle-8.11.1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting Kotlin Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

# Build first
bash "$SCRIPT_DIR/build-server.sh"

# Run server using gradle task
gradle runServerExe --args="--port $PORT --path $PATH_ENDPOINT"
