# Dart Audio Stream Client

A WebSocket-based audio stream cache client implemented in Dart with async/await.

## Prerequisites

- **Dart SDK**: Version 3.0 or higher

## Dependencies

This implementation uses:
- **web_socket_channel**: 2.4.0 - WebSocket communication
- **args**: 2.4.0 - Command-line argument parsing
- **crypto**: 3.0.0 - SHA-256 hashing
- **intl**: 0.18.0 - Date formatting

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
1. Get dependencies via pub
2. Compile Dart code to native executable

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
- `--verbose` or `-v`: Enable verbose logging (optional)
- `--help` or `-h`: Display help message

## Architecture

The client follows a modular architecture:

- **CliParser**: Command-line argument parsing using args package
- **WebSocketClient**: WebSocket connection management using web_socket_channel
- **FileManager**: File I/O operations with SHA-256 checksums using crypto
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
# Run tests with Dart
dart test
```

## Platform Support

- ✅ Windows 10/11
- ✅ Ubuntu 20.04/22.04
- ✅ macOS 12+

## Implementation Notes

- Uses Dart's native async/await for concurrency
- web_socket_channel for WebSocket communication
- crypto package for SHA-256 computation
- 8KB upload chunks to avoid WebSocket frame fragmentation
- args package for CLI interface

## Troubleshooting

### Build Fails

- Ensure Dart SDK 3.0+ is installed: `dart --version`
- Get dependencies: `dart pub get`
- Clean build: `dart pub cache clean`

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
