# Audio Stream Client - Go Implementation

A high-performance audio stream cache client implemented in Go using goroutines and channels.

## Features

- WebSocket-based stream
- 64KB chunked upload/download
- SHA-256 integrity verification
- Performance monitoring and reporting
- Cross-platform support (Windows, Linux, macOS)
- Concurrent operations with goroutines

## Prerequisites

- Go 1.25 or higher

### Installing Go

**macOS:**
```bash
brew install go
```

**Linux:**
```bash
# Download from https://golang.org/dl/
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

**Windows:**
Download and install from [https://golang.org/dl/](https://golang.org/dl/)

## Dependencies

- `github.com/gorilla/websocket` - WebSocket client
- `github.com/spf13/cobra` - Command-line interface

## Building

### Unix/Linux/macOS

```bash
./build.sh
```

### Windows (PowerShell)

```powershell
.\build.ps1
```

### Manual Build

```bash
# Download dependencies
go mod download

# Build client
go build -o bin/client ./cmd/client

# Build server
go build -o bin/server ./cmd/server

# Or build both
go build ./...
```

## Running

### Unix/Linux/macOS

```bash
# Basic usage
./run-client.sh --input audio/input/test.mp3

# Custom server
./run-client.sh --input audio/input/test.mp3 --server ws://192.168.1.100:8080/audio

# Custom output path
./run-client.sh --input audio/input/test.mp3 --output /tmp/output.mp3

# Verbose mode
./run-client.sh --input audio/input/test.mp3 --verbose
```

### Windows (PowerShell)

```powershell
# Basic usage
.\run-client.ps1 --input audio\input\test.mp3

# Custom server
.\run-client.ps1 --input audio\input\test.mp3 --server ws://192.168.1.100:8080/audio

# Custom output path
.\run-client.ps1 --input audio\input\test.mp3 --output C:\temp\output.mp3

# Verbose mode
.\run-client.ps1 --input audio\input\test.mp3 --verbose
```

### Direct Execution

```bash
# Unix/Linux/macOS - Client
./bin/client --input audio/input/test.mp3

# Unix/Linux/macOS - Server
./bin/server

# Windows - Client
.\bin\client.exe --input audio\input\test.mp3

# Windows - Server
.\bin\server.exe
```

## Command-Line Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--input <FILE>` | Input audio file path | - | Yes |
| `--server <URI>` | WebSocket server URI | `ws://localhost:8080/audio` | No |
| `--output <FILE>` | Output file path | `audio/output/output-{timestamp}-{filename}` | No |
| `--verbose` / `-v` | Enable verbose logging | Disabled | No |
| `--help` / `-h` | Display help message | - | No |

## Project Structure

```
hello-go/
├── go.mod                  # Go module definition
├── go.sum                  # Dependency checksums
├── cmd/
│   ├── client/
│   │   └── main.go        # Client entry point
│   └── server/
│       └── main.go        # Server entry point
├── src/
│   ├── cli/                # Command-line argument parsing
│   ├── client/
│   │   ├── audio_client_application.go
│   │   ├── core/
│   │   │   ├── chunk_manager.go
│   │   │   ├── file_manager.go
│   │   │   ├── upload_manager.go
│   │   │   ├── download_manager.go
│   │   │   └── websocket_client.go
│   │   └── util/
│   │       ├── file_util.go
│   │       ├── performance_monitor.go
│   │       ├── stream_id_generator.go
│   │       └── verification_module.go
│   ├── server/
│   │   ├── audio_server_application.go
│   │   ├── handler/
│   │   │   └── websocket_message_handler.go
│   │   ├── memory/
│   │   │   ├── stream_manager.go
│   │   │   ├── stream_context.go
│   │   │   ├── memory_mapped_cache.go
│   │   │   └── memory_pool_manager.go
│   │   └── network/
│   │       └── audio_websocket_server.go
│   └── logger/             # Logging utilities
├── cache/                  # Memory-mapped cache files (runtime)
└── README.md               # This file
```

## Performance

The client targets the following performance metrics:

- **Upload Throughput**: > 100 Mbps
- **Download Throughput**: > 200 Mbps

Actual performance depends on:
- Network conditions
- Disk I/O speed
- System resources
- File size

## Error Handling

The client provides detailed error messages for common issues:

- **Connection Errors**: Server unreachable, connection refused
- **File I/O Errors**: File not found, permission denied
- **Protocol Errors**: Invalid server responses
- **Verification Errors**: Checksum mismatch, size mismatch

All errors are logged with timestamps and context information.

## Platform Support

- ✅ Windows 10/11
- ✅ Ubuntu 20.04/22.04
- ✅ macOS 12+

## Troubleshooting

### Build Errors

**Problem**: `go: command not found`
**Solution**: Install Go (see Prerequisites)

**Problem**: Module download errors
**Solution**: Ensure you have internet connectivity and run `go mod download`

### Runtime Errors

**Problem**: Connection refused
**Solution**: Ensure the server is running and accessible

**Problem**: File not found
**Solution**: Check the input file path is correct

**Problem**: Permission denied
**Solution**: Ensure you have read/write permissions for input/output files

## License

This implementation is part of the Memory-Mapped Cache project.

## See Also

- [Rust Implementation](../hello-rust/)
- [C++ Implementation](../hello-cpp/)
- [Java Implementation](../hello-java/)
- [Project Documentation](../docs/)
