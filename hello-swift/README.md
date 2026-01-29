# Swift Audio Stream Client

A WebSocket-based audio file transfer client implemented in Swift with async/await.

## Prerequisites

- **Swift**: Version 5.9 or higher
- **macOS**: Version 13.0 or higher (for URLSessionWebSocketTask)

## Dependencies

This implementation uses:
- **Swift Standard Library**: Built-in async/await support
- **Foundation**: URLSession for WebSocket communication
- **CryptoKit**: Built-in SHA-256 hashing
- **ArgumentParser**: 1.3.0 - Command-line argument parsing

## Building

### Unix/Linux/macOS

```bash
./build.sh
```

### Windows (PowerShell)

```powershell
.\build.ps1
```

The build script will:
1. Resolve dependencies via Swift Package Manager
2. Compile Swift source code in release mode
3. Create an executable binary

## Running

### Unix/Linux/macOS

```bash
# Basic usage
./run-client.sh --input ../audio/input/test.mp3

# Custom server
./run-client.sh --input ../audio/input/test.mp3 --server ws://192.168.1.100:8080/audio

# Custom output path
./run-client.sh --input ../audio/input/test.mp3 --output /tmp/output.mp3

# Verbose mode
./run-client.sh --input ../audio/input/test.mp3 --verbose
```

### Windows (PowerShell)

```powershell
# Basic usage
.\run-client.ps1 --input ..\audio\input\test.mp3

# Custom server
.\run-client.ps1 --input ..\audio\input\test.mp3 --server ws://192.168.1.100:8080/audio

# Custom output path
.\run-client.ps1 --input ..\audio\input\test.mp3 --output C:\temp\output.mp3

# Verbose mode
.\run-client.ps1 --input ..\audio\input\test.mp3 --verbose
```

## Command-Line Options

- `--input <path>`: Path to input audio file (required)
- `--output <path>`: Path to output audio file (optional, default: `audio/output/output-<timestamp>-<filename>`)
- `--server <uri>`: WebSocket server URI (optional, default: `ws://localhost:8080/audio`)
- `--verbose`: Enable verbose logging (optional)
- `--help`: Display help message

## Architecture

The client follows a modular architecture:

- **CliParser**: Command-line argument parsing using ArgumentParser
- **WebSocketClient**: WebSocket connection management using URLSessionWebSocketTask
- **AudioFileManager**: File I/O operations with SHA-256 checksums using CryptoKit
- **Upload**: Upload workflow with 8KB chunks
- **Download**: Download workflow with GET requests
- **Verification**: File integrity verification
- **Performance**: Performance monitoring and reporting
- **Logger**: Structured logging with timestamps

## Workflow

1. **Parse Arguments**: Validate input file and configuration
2. **Connect**: Establish WebSocket connection to server
3. **Upload**: Send file in 8KB chunks with progress reporting
4. **Download**: Request and receive file chunks
5. **Verify**: Compare SHA-256 checksums and file sizes
6. **Report**: Display performance metrics (throughput, duration)

## Testing

```bash
# Run tests with Swift Package Manager
swift test
```

## Platform Support

- ✅ macOS 13+
- ⚠️ Linux (requires alternative WebSocket library)
- ⚠️ Windows (requires alternative WebSocket library)

## Implementation Notes

- Uses Swift's native async/await for concurrency
- URLSessionWebSocketTask for WebSocket communication (macOS 13+ only)
- CryptoKit for SHA-256 computation
- 8KB upload chunks to avoid WebSocket frame fragmentation
- ArgumentParser for elegant CLI interface

## Troubleshooting

### Build Fails

- Ensure Swift 5.9+ is installed: `swift --version`
- Ensure macOS 13+ for URLSessionWebSocketTask
- Clean build directory: `swift package clean`

### Connection Refused

- Ensure WebSocket server is running on port 8080
- Check server URI is correct
- Verify network connectivity

### File Not Found

- Ensure input file path is correct
- Use absolute paths or paths relative to project root
- Check file permissions

## License

Part of the cross-language audio streaming project.
