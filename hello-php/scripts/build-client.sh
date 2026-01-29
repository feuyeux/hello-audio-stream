#!/bin/bash

# Build Client - PHP Implementation (Unix/Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Building PHP Audio Stream Client..."

# Install dependencies
if [ ! -d "vendor" ]; then
    echo "Installing dependencies..."
    composer install
else
    echo "Regenerating autoload files..."
    composer dump-autoload
fi

echo "Build completed successfully!"
echo "Run with: php audio_stream_client.php"
