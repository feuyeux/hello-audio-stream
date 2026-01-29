#!/bin/bash

# Run Client - Python Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Please run build.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Run client
echo "Starting Audio Stream Client (Python)..."

python -m audio_client.audio_client_application "$@"
