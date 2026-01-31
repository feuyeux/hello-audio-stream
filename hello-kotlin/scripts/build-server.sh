#!/bin/bash

# Build Server - Kotlin Implementation (Unix/Linux/macOS)

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

echo "Building Kotlin Audio Stream..."

# Build with Gradle
gradle build -x test

echo "Build completed successfully!"
