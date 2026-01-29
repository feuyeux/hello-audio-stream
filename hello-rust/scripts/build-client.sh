#!/bin/bash

# Build Client - Rust Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Rust Audio Stream Client..."

# Build client
cargo build --release --bin audio_stream_client

echo "Build completed successfully!"
echo "Executable: target/release/audio_stream_client"
