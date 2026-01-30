#!/bin/bash

# Run Client - Python Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SERVER_URI=${1:-ws://localhost:8080/audio}
INPUT_FILE=${2:-../audio/input/hello.mp3}

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Please run build.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Run client
echo "Starting Audio Stream Client (Python)..."
echo "Server: $SERVER_URI"
echo "Input: $INPUT_FILE"

python -m audio_client.audio_client_application --server "$SERVER_URI" --input "$INPUT_FILE"
