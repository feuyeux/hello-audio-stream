#!/bin/bash

# Build Client - Swift Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Configure Swift path based on OS
if [[ "$(uname)" == "Linux" ]]; then
    export PATH="/home/hanl5/zoo/swift-6.2.3/usr/bin:$PATH"
fi

echo "Building Swift Audio Stream Client..."

# Build client
swift build -c release --product audio_stream_client

echo "Build completed successfully!"
echo "Executable: .build/release/audio_stream_client"
