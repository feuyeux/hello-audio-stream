# Audio Stream Cache Client - TypeScript Implementation

TypeScript implementation of the audio stream cache client using WebSocket protocol.

## Features

- ✅ WebSocket-based stream
- ✅ Chunked upload/download (8KB upload, 64KB download)
- ✅ SHA-256 file verification
- ✅ Performance monitoring
- ✅ Verbose logging support
- ✅ Cross-platform support (Windows, macOS, Linux)

## Requirements

- Node.js 18+ or 20+
- npm or yarn

## Installation

```bash
# Install dependencies
npm install

# Build the project
npm run build
```

## Usage

### Basic Usage

```bash
# Using npm script
npm start -- --input path/to/audio.mp3

# Using run script
./run-client.sh --input path/to/audio.mp3

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
npm start -- --input audio/input/hello.mp3

# Specify custom server
npm start -- --input audio/input/hello.mp3 --server ws://example.com:8080/audio

# Specify output path
npm start -- --input audio/input/hello.mp3 --output audio/output/result.mp3

# Enable verbose logging
npm start -- --input audio/input/hello.mp3 --verbose
```

## Building

### Unix/Linux/macOS

```bash
chmod +x build.sh
./build.sh
```

### Windows (PowerShell)

```powershell
.\build.ps1
```

## Development

```bash
# Run in development mode with ts-node
npm run dev -- --input path/to/audio.mp3

# Clean build artifacts
npm run clean

# Rebuild
npm run build
```

## Architecture

The TypeScript implementation follows a modular architecture:

- **cli.ts** - Command-line argument parsing using commander
- **websocket.ts** - WebSocket client with async/await
- **file.ts** - File I/O operations with fs/promises
- **performance.ts** - Performance metrics tracking
- **logger.ts** - Structured logging with timestamps
- **types.ts** - TypeScript type definitions
- **index.ts** - Main application entry point

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

```typescript
interface ControlMessage {
  type: 'start' | 'started' | 'stop' | 'stopped' | 'get' | 'error';
  streamId?: string;
  offset?: number;
  length?: number;
  message?: string;
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
- **typescript** (^5.3.3) - TypeScript compiler
- **@types/node** (^20.11.0) - Node.js type definitions
- **@types/ws** (^8.5.10) - ws library type definitions

## License

MIT
