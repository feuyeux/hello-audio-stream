# Audio Stream Cache Client - Node.js Implementation

Pure JavaScript implementation of the audio file transfer client using WebSocket protocol.

## Features

- ✅ WebSocket-based file transfer
- ✅ Chunked upload/download (8KB upload, 64KB download)
- ✅ SHA-256 file verification
- ✅ Performance monitoring
- ✅ Verbose logging support
- ✅ Cross-platform support (Windows, macOS, Linux)
- ✅ No build step required (pure JavaScript)

## Requirements

- Node.js 18+ or 20+
- npm

## Installation

```bash
# Install dependencies
npm install
```

## Usage

### Basic Usage

```bash
# Using npm script
npm start -- --input path/to/audio.mp3

# Using run script
./run-client.sh --input path/to/audio.mp3

# Direct execution
node src/index.js --input path/to/audio.mp3

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
  --version             Display version information
```

### Examples

```bash
# Upload and download with default server
node src/index.js --input audio/input/hello.mp3

# Specify custom server
node src/index.js --input audio/input/hello.mp3 --server ws://example.com:8080/audio

# Specify output path
node src/index.js --input audio/input/hello.mp3 --output audio/output/result.mp3

# Enable verbose logging
node src/index.js --input audio/input/hello.mp3 --verbose
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

The Node.js implementation uses ES modules and follows a modular architecture:

- **cli.js** - Command-line argument parsing using commander
- **core/WebSocketClient.js** - WebSocket client with async/await
- **core/ChunkManager.js** - Data chunk management
- **core/FileManager.js** - File I/O operations with fs/promises
- **core/UploadManager.js** - Upload workflow coordination
- **core/DownloadManager.js** - Download workflow coordination
- **util/ErrorHandler.js** - Centralized error handling
- **util/PerformanceMonitor.js** - Performance metrics tracking
- **util/StreamIdGenerator.js** - Unique stream identifier generation
- **util/VerificationModule.js** - SHA-256 checksum verification
- **AudioClientApplication.js** - Main application entry point

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

```javascript
{
  type: 'start' | 'started' | 'stop' | 'stopped' | 'get' | 'error',
  streamId?: string,
  offset?: number,
  length?: number,
  message?: string
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

- **ws** (^8.16.0) - WebSocket client library
- **commander** (^11.1.0) - CLI argument parsing

## Differences from TypeScript Version

- No compilation step required
- Uses ES modules (`type: "module"` in package.json)
- Pure JavaScript (no type annotations)
- Slightly faster startup time (no compilation)

## License

MIT
