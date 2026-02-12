#!/bin/bash

# Run Client - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Ubuntu/Linux
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export GRADLE_HOME=/home/hanl5/zoo/gradle-8.11.1
fi

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting Kotlin Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

JAR_FILE=$(ls build/libs/*.jar 2>/dev/null | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
    JAR_FILE=$(ls build/libs/*.jar 2>/dev/null | head -1)
fi

if [ -z "$JAR_FILE" ]; then
    echo "Error: Kotlin client JAR not found after build."
    exit 1
fi

"$JAVA_HOME/bin/java" -cp "$JAR_FILE" MainKt --server "$SERVER_URI" --input "$INPUT_FILE"
