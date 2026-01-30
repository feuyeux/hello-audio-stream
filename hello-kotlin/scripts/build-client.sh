#!/bin/bash

# Build Client - Kotlin Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Kotlin Audio Stream Client..."

# Set Java and Gradle versions
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export GRADLE_HOME=/home/hanl5/zoo/gradle-8.11.1

# Build with Gradle
"$GRADLE_HOME/bin/gradle" installDist

echo "Build completed successfully!"
echo "Executable: client/build/install/client/bin/client"
