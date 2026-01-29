# PHP Audio Stream Client

A WebSocket-based audio file transfer client implemented in PHP with ReactPHP.

## Prerequisites

- **PHP**: Version 8.1 or higher
- **Composer**: For dependency management

## Dependencies

This implementation uses:
- **ratchet/pawl**: 0.4 - WebSocket client
- **react/event-loop**: 1.5 - Event loop for async operations
- **react/promise**: 3.2 - Promise-based async programming

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
1. Install dependencies via Composer
2. Optimize autoloader

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

- **CliParser**: Command-line argument parsing
- **WebSocketClient**: WebSocket connection management using Ratchet/Pawl
- **FileManager**: File I/O operations with SHA-256 checksums
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
# Run tests with PHPUnit (if configured)
composer test
```

## Platform Support

- ✅ Windows 10/11
- ✅ Ubuntu 20.04/22.04
- ✅ macOS 12+

## Implementation Notes

- Uses ReactPHP event loop for async operations
- Ratchet/Pawl for WebSocket communication
- Promise-based async programming
- 8KB upload chunks to avoid WebSocket frame fragmentation
- Built-in hash_file() for SHA-256 computation

## Known Issues

### Binary WebSocket Frame Support

**Status**: Under Investigation

The current implementation has an issue with sending binary WebSocket frames using Ratchet/Pawl. The server reports "bytes are not UTF-8" errors, indicating that binary data is being sent as text frames instead of binary frames.

**Symptoms**:
- Upload appears to complete but connection closes before receiving STOP_ACK
- Server logs show: `CorruptedWebSocketFrameException: bytes are not UTF-8`
- Client hangs after upload phase

**Attempted Solutions**:
1. Using `send($data, true)` - second parameter should indicate binary frame
2. Using RFC6455 Frame class directly
3. Using event loop's `futureTick` to schedule sends

**Root Cause**:
Ratchet/Pawl may not properly support binary WebSocket frames in the current version (0.4), or there may be a configuration issue.

**Workaround**:
None currently available. This requires either:
- Finding the correct API to send binary frames in Ratchet/Pawl
- Switching to a different PHP WebSocket library that better supports binary frames
- Updating Ratchet/Pawl to a newer version if available

**Impact**:
- File upload does not complete successfully
- End-to-end test cannot pass
- PHP implementation is not production-ready

This issue does not affect the overall architecture or design, which correctly follows the async/promise pattern used in other implementations.

## Troubleshooting

### Build Fails

- Ensure PHP 8.1+ is installed: `php --version`
- Ensure Composer is installed: `composer --version`
- Install dependencies: `composer install`

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
