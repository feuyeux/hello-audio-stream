# Audio Stream Cache System - C++ Implementation

This is the C++ implementation of the Multi-Language Audio Stream Cache System, a high-performance WebSocket-based audio streaming solution that supports chunked file upload/download, memory-mapped file caching, and end-to-end verification.

## Features

- **WebSocket Communication**: Persistent bidirectional communication using websocketpp
- **Memory-Mapped Files**: Zero-copy I/O using platform-specific mmap APIs
- **Chunked Transfer**: 64KB chunks for efficient streaming
- **Concurrent Streams**: Support for multiple simultaneous streams
- **Data Verification**: MD5/SHA-256 checksums for integrity checking
- **Performance Metrics**: Detailed throughput and timing measurements
- **Cross-Platform**: Supports Windows, Linux, and macOS
- **Property-Based Testing**: RapidCheck integration for comprehensive testing

## Project Structure

```
hello-cpp/
├── client/                 # Client implementation
│   ├── include/           # Client headers
│   │   ├── websocket_client.h
│   │   ├── file_manager.h
│   │   ├── chunk_manager.h
│   │   ├── verification_module.h
│   │   ├── performance_monitor.h
│   │   ├── stream_id_generator.h
│   │   ├── download_manager.h
│   │   ├── upload_manager.h
│   │   ├── error_handler.h
│   │   ├── logging_system.h
│   │   └── common_types.h
│   ├── src/               # Client source files
│   │   ├── main.cpp
│   │   ├── websocket_client.cpp
│   │   ├── file_manager.cpp
│   │   ├── chunk_manager.cpp
│   │   ├── verification_module.cpp
│   │   ├── performance_monitor.cpp
│   │   ├── stream_id_generator.cpp
│   │   ├── download_manager.cpp
│   │   ├── upload_manager.cpp
│   │   ├── error_handler.cpp
│   │   └── logging_system.cpp
│   ├── tests/             # Client tests
│   │   ├── websocket_client_test.cpp
│   │   ├── file_manager_test.cpp
│   │   ├── chunk_manager_test.cpp
│   │   ├── verification_module_test.cpp
│   │   ├── performance_monitor_test.cpp
│   │   ├── stream_id_generator_test.cpp
│   │   ├── download_manager_test.cpp
│   │   ├── error_handler_test.cpp
│   │   ├── logging_system_test.cpp
│   │   └── property_tests.cpp
│   └── CMakeLists.txt
├── server/                # Server implementation
│   ├── include/           # Server headers
│   │   ├── websocket_server.h
│   │   ├── stream_manager.h
│   │   ├── memory_mapped_cache.h
│   │   ├── memory_pool_manager.h
│   │   ├── stream_context.h
│   │   └── common_types.h
│   ├── src/               # Server source files
│   │   ├── main.cpp
│   │   ├── websocket_server.cpp
│   │   ├── stream_manager.cpp
│   │   ├── memory_mapped_cache.cpp
│   │   └── memory_pool_manager.cpp
│   ├── tests/             # Server tests
│   │   ├── websocket_server_test.cpp
│   │   ├── stream_manager_test.cpp
│   │   ├── memory_mapped_cache_test.cpp
│   │   ├── memory_pool_manager_test.cpp
│   │   └── property_tests.cpp
│   └── CMakeLists.txt
├── build.sh               # Unix/Linux/macOS build script
├── build.ps1              # Windows build script
├── download-deps.sh       # Unix/Linux/macOS dependency download script
├── download-deps.ps1      # Windows dependency download script
├── run-server.sh          # Unix/Linux/macOS server run script
├── run-server.ps1         # Windows server run script
├── run-client.sh          # Unix/Linux/macOS client run script
├── run-client.ps1         # Windows client run script
├── CMakeLists.txt         # Root CMake configuration
└── README.md              # This file
```

## Requirements

- **C++ Compiler**: C++20 support required
  - GCC 10+ or Clang 11+ (Linux/macOS)
  - MSVC 2019+ (Windows)
- **CMake**: Version 3.20 or higher
- **Dependencies** (automatically fetched by CMake):
  - websocketpp 0.8.2
  - spdlog 1.14.1
  - nlohmann/json 3.11.3
  - Google Test 1.14.0
  - RapidCheck (latest)

## Building

### Linux/macOS

```bash
# Build with default settings (Release mode)
./build.sh

# Build in Debug mode
./build.sh Debug

# Clean build
./build.sh Release clean
```

### Windows

```cmd
# Build with default settings (Release mode)
build.ps1

# Build in Debug mode
build.ps1 Debug

# Clean build
build.ps1 Release clean
```

### Manual Build

```bash
# Create build directory
mkdir build
cd build

# Configure
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build . --config Release

# Run tests
ctest -C Release --output-on-failure
```

## Running

### Server

The server listens for WebSocket connections and manages audio stream caching.

**Linux/macOS:**
```bash
# Start server on default port (8080)
./run-server.sh

# Start server on custom port
./run-server.sh 9000

# Start server with custom path
./run-server.sh 8080 /audio
```

**Windows:**
```cmd
# Start server on default port (8080)
run-server.ps1

# Start server on custom port
run-server.ps1 9000

# Start server with custom path
run-server.ps1 8080 /audio
```

### Client

The client uploads a file, downloads it back, and verifies integrity.

**Linux/macOS:**
```bash
# Upload and download a file
./run-client.sh ws://localhost:8080/audio input.mp3 output.mp3

# Connect to remote server
./run-client.sh ws://example.com:8080/audio input.mp3 output.mp3
```

**Windows:**
```cmd
# Upload and download a file
run-client.ps1 ws://localhost:8080/audio input.mp3 output.mp3

# Connect to remote server
run-client.ps1 ws://example.com:8080/audio input.mp3 output.mp3
```

## Testing

The project includes both unit tests and property-based tests.

```bash
# Run all tests
cd build
ctest -C Release --output-on-failure

# Run specific test suite
./bin/client_tests
./bin/server_tests
./bin/client_property_tests
./bin/server_property_tests

# Run with verbose output
ctest -C Release -V
```

## WebSocket Protocol

### Control Messages (JSON Text Frames)

**START** - Begin uploading a stream:
```json
{"type": "START", "streamId": "stream-1234567890-abcd"}
```

**STARTED** - Server confirms stream started:
```json
{"type": "STARTED", "message": "Stream started successfully", "streamId": "stream-1234567890-abcd"}
```

**STOP** - End uploading a stream:
```json
{"type": "STOP", "streamId": "stream-1234567890-abcd"}
```

**STOPPED** - Server confirms stream stopped:
```json
{"type": "stopped", "message": "Stream stopped successfully", "streamId": "stream-1234567890-abcd"}
```

**GET** - Request data from cache:
```json
{"type": "GET", "streamId": "stream-1234567890-abcd", "offset": 0, "length": 65536}
```

**ERROR** - Server reports an error:
```json
{"type": "error", "message": "Stream not found: stream-1234567890-abcd"}
```

### Binary Frames

Binary frames contain raw audio data chunks (up to 64KB each) without additional framing.

## Architecture

### Client Components

- **WebSocketClient**: Manages WebSocket connection with automatic reconnection
- **FileManager**: Handles file I/O operations
- **ChunkManager**: Splits files into chunks and assembles downloaded data
- **VerificationModule**: Computes checksums and verifies file integrity
- **PerformanceMonitor**: Tracks upload/download metrics
- **StreamIdGenerator**: Generates unique stream identifiers
- **DownloadManager**: Manages file download workflow
- **UploadManager**: Manages file upload workflow
- **ErrorHandler**: Centralized error handling and reporting
- **LoggingSystem**: Configurable logging infrastructure

### Server Components

- **WebSocketServer**: Accepts connections and routes messages
- **StreamManager**: Manages active streams and cache files
- **MemoryMappedCache**: Provides zero-copy file access using mmap
- **MemoryPoolManager**: Pre-allocates buffers for efficient memory usage
- **StreamContext**: Maintains stream state and metadata

## Memory-Mapped Files

The implementation uses platform-specific APIs for memory-mapped files:

- **Linux/macOS**: `mmap()`, `munmap()` from `<sys/mman.h>`
- **Windows**: `CreateFileMapping()`, `MapViewOfFile()` from Win32 API

This provides zero-copy I/O for efficient handling of large audio files.

## Performance Targets

- **Upload Throughput**: > 100 Mbps
- **Download Throughput**: > 200 Mbps
- **Concurrent Streams**: > 100 simultaneous streams
- **Memory per Stream**: < 1 MB (excluding cached file)

## Configuration

### Server Configuration

- **Port**: Default 8080 (configurable via command-line)
- **Path**: Default /audio (configurable via command-line)
- **Cache Directory**: ./cache (created automatically)

### Client Configuration

- **Chunk Size**: 65536 bytes (64KB)
- **Connection Timeout**: 5000ms
- **Max Retries**: 10

## Cross-Language Compatibility

This C++ implementation is compatible with the Java reference implementation and other language implementations in this project. Clients and servers can interoperate regardless of implementation language.

## License

Part of the Multi-Language Audio Stream Cache System project.
