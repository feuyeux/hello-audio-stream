#!/bin/bash

# Run Client - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Set Java and Gradle versions
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export GRADLE_HOME=/home/hanl5/zoo/gradle-8.11.1

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

echo "Starting Kotlin Client..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

if [ ! -f "build/install/hello-kotlin/bin/hello-kotlin" ]; then
    echo "Executable not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
fi

build/install/hello-kotlin/bin/hello-kotlin --server "$SERVER_URI" --input "$INPUT_FILE"
