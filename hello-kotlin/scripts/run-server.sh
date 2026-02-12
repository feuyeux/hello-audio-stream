#!/bin/bash

# Run Server - Kotlin Implementation (Unix/Linux/macOS)

set -e

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home"
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

JAR_FILE=$(ls build/libs/*.jar 2>/dev/null | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-server.sh"
    JAR_FILE=$(ls build/libs/*.jar 2>/dev/null | head -1)
fi

if [ -z "$JAR_FILE" ]; then
    echo "Error: Kotlin server JAR not found after build."
    exit 1
fi

# Run server directly from built artifact
"$JAVA_HOME/bin/java" -cp "$JAR_FILE" server.MainKt --port "$PORT" --path "$PATH_ENDPOINT"
