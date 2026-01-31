# Audio Stream Cache Client - Python Implementation

Python implementation of the audio stream cache client using WebSocket protocol with asyncio.

## Features

- ✅ WebSocket-based stream with asyncio
- ✅ Chunked upload/download (8KB upload, 64KB download)
- ✅ SHA-256 file verification
- ✅ Performance monitoring
- ✅ Verbose logging support
- ✅ Cross-platform support (Windows, macOS, Linux)
- ✅ Virtual environment support

## Requirements

- Python 3.8+
- pip

## Installation

```bash
# Create virtual environment and install dependencies
./build.sh

# Or manually:
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -e .
```

## Usage

### Basic Usage

```bash
# Using run script (recommended)
./run-client.sh --input path/to/audio.mp3

# Using module directly
source venv/bin/activate
python -m audio_client.audio_client_application --input path/to/audio.mp3

# Using installed command
source venv/bin/activate
audio-stream-client --input path/to/audio.mp3

# Windows PowerShell
.\run-client.ps1 --input path\to\audio.mp3
```

### Command-Line Options

```
Options:
  -i, --input <file>    Input audio file path (required)
  -s, --server <uri>    WebSocket server URI (default: ws://localhost:8080/audio)
  -o, --output <file>   Output file path (auto-generated if not specified)
  -v, --verbose         Enable verbose logging
  -h, --help            Display help information
```

### Examples

```bash
# Upload and download with default server
./run-client.sh --input audio/input/hello.mp3

# Specify custom server
./run-client.sh --input audio/input/hello.mp3 --server ws://example.com:8080/audio

# Specify output path
./run-client.sh --input audio/input/hello.mp3 --output audio/output/result.mp3

# Enable verbose logging
./run-client.sh --input audio/input/hello.mp3 --verbose
```

## Building

### Unix/Linux/macOS

```bash
chmod +x build.sh run-client.sh
./build.sh
```

### Windows (PowerShell)

```powershell
.\build.ps1
```

## Architecture

The Python implementation uses asyncio and follows a modular architecture:

- **cli.py** - Command-line argument parsing with argparse
- **core/websocket_client.py** - WebSocket client with asyncio
- **core/chunk_manager.py** - Data chunk management
- **core/file_manager.py** - File I/O operations
- **core/upload_manager.py** - Upload workflow coordination
- **core/download_manager.py** - Download workflow coordination
- **util/verification_module.py** - SHA-256 checksum verification
- **util/performance_monitor.py** - Performance metrics tracking
- **util/error_handler.py** - Centralized error handling
- **util/stream_id_generator.py** - Unique stream identifier generation
- **logger.py** - Structured logging with timestamps
- **audio_client_application.py** - Main application entry point

## Protocol

### Upload Flow

1. Send START control message with stream ID
2. Wait for STARTED acknowledgment
3. Send file data in 8KB binary chunks
4. Send STOP control message
5. Wait for STOPPED acknowledgment

### Download Flow

1. Send GET control message with offset and length
2. Receive binary data chunk (8KB from server)
3. Repeat until all data received

### Control Messages

All control messages are JSON-formatted text messages:

```python
{
    'type': 'start' | 'started' | 'stop' | 'stopped' | 'get' | 'error',
    'streamId': str,  # optional
    'offset': int,    # optional
    'length': int,    # optional
    'message': str    # optional
}
```

## Performance

The client tracks and reports:
- Upload duration and throughput (Mbps)
- Download duration and throughput (Mbps)
- Total duration and average throughput

Performance targets:
- Upload: >100 Mbps
- Download: >200 Mbps

## Error Handling

The client handles:
- Connection failures with clear error messages
- File I/O errors
- Protocol errors from server
- Verification failures

## Dependencies

- **websockets** (>=12.0) - Async WebSocket client library

## Development

```bash
# Activate virtual environment
source venv/bin/activate

# Run directly
python -m audio_client.audio_client_application --input path/to/audio.mp3

# Run tests (if available)
pytest
```

## Python Features Used

- **asyncio** - Asynchronous I/O for WebSocket communication
- **Type hints** - For better code documentation
- **Context managers** - For proper resource management
- **Pathlib** - Modern path handling
- **hashlib** - SHA-256 checksum calculation

## License

MIT
