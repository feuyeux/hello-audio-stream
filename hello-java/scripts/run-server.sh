#!/bin/bash

# Run Server - Java Implementation (Unix/Linux/macOS)

set -e

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JAVA_HOME="/opt/homebrew/opt/java/libexec/openjdk.jdk/Contents/Home"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

echo "Starting Java Server on port $PORT..."
echo "Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

cd audio-stream-server

JAR_FILE=$(ls target/audio-stream-server*.jar 2>/dev/null | grep -v original | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
    JAR_FILE=$(ls target/audio-stream-server*.jar 2>/dev/null | grep -v original | head -1)
fi

java --enable-preview -jar "$JAR_FILE" "$PORT" "$PATH_ENDPOINT"
