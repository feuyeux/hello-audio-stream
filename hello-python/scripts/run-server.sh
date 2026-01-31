#!/bin/bash

# Run Server - Python Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

PORT=${1:-8080}
PATH_ENDPOINT=${2:-/audio}

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Please run build.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

if [ ! -d "cache" ]; then
    mkdir -p cache
fi

# Run server
echo "Starting Audio Stream Server (Python)..."
echo "Port: $PORT, Endpoint: $PATH_ENDPOINT"
echo "Press Ctrl+C to stop"
echo ""

python -m src.audio_server.main --port "$PORT" --path "$PATH_ENDPOINT"
