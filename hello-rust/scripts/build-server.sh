#!/bin/bash

# Build Server - Rust Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building Rust Audio Stream Server..."

# Build server
cargo build --release --bin audio_stream_server

echo "Build completed successfully!"
echo "Executable: target/release/audio_stream_server"
