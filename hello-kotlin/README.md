# Kotlin Audio Stream Client

A WebSocket-based audio stream cache client implemented in Kotlin with coroutines.

## Prerequisites

- **Java Development Kit (JDK)**: Version 21 or higher
- **Gradle**: Version 8.0 or higher (system installation required)

## Dependencies

This implementation uses:
- **Kotlin**: 1.9.25
- **Kotlinx Coroutines**: 1.8.1 - For async operations
- **Kotlinx Serialization**: 1.6.3 - For JSON serialization
- **Ktor Client**: 2.3.12 - For WebSocket communication
- **Java MessageDigest**: Built-in - For SHA-256 checksums

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
1. Clean previous builds
2. Compile Kotlin source code
3. Run tests (if any)
4. Create an executable JAR file

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

- **CliParser**: Command-line argument parsing
- **WebSocketClient**: WebSocket connection management using Ktor
- **FileManager**: File I/O operations with SHA-256 checksums
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

 

## Platform Support

- ✅ Windows 10/11
- ✅ Ubuntu 20.04/22.04
- ✅ macOS 12+

## Implementation Notes

- Uses Kotlin coroutines for async operations
- Ktor client for WebSocket communication
- 8KB upload chunks to avoid WebSocket frame fragmentation
- Incremental SHA-256 computation for memory efficiency
- Structured logging with timestamps and log levels

## Troubleshooting

### Build Fails

- Ensure JDK 21+ is installed: `java -version`
- Ensure Gradle is accessible: `gradle --version`
- Clean build directory: `gradle clean`

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
