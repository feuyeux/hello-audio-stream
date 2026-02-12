#!/bin/bash

# Run Client - Java Implementation (Unix/Linux/macOS)

set -e

# Set JAVA_HOME based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home"
elif [[ -z "$JAVA_HOME" && "$OSTYPE" == "linux"* ]]; then
    JAVA_BIN=$(readlink -f "$(which java)" 2>/dev/null)
    if [[ -n "$JAVA_BIN" ]]; then
        export JAVA_HOME="${JAVA_BIN%/bin/java}"
    fi
fi
export PATH="$JAVA_HOME/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Starting Java Client..."

cd audio-stream-client

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../../audio/input/hello.mp3}

JAR_FILE=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "JAR not found. Building..."
    bash "$SCRIPT_DIR/build-client.sh"
    JAR_FILE=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
fi

echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

"$JAVA_HOME/bin/java" --enable-preview -jar "$JAR_FILE" --server "$SERVER_URI" --input "$INPUT_FILE"
