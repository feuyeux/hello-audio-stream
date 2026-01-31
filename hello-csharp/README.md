# Audio Stream Cache Client - C# Implementation

C# implementation of the audio stream cache client that uploads, downloads, and verifies audio files via WebSocket.

## Features

- **Upload**: Stream audio files to server in 8KB chunks
- **Download**: Retrieve audio files from server
- **Verification**: SHA-256 checksum validation
- **Performance Monitoring**: Upload/download throughput measurement
- **Progress Reporting**: Real-time progress updates at 25%, 50%, 75%, 100%
- **Cross-platform**: Supports Windows, Linux, and macOS

## Prerequisites

- .NET 8.0 SDK or later
- WebSocket server running on port 8080

## Project Structure

```
hello-csharp/
├── src/
│   ├── Program.cs          # Main entry point
│   ├── CliParser.cs        # Command-line argument parser
│   ├── Logger.cs           # Logging utilities
│   ├── Types.cs            # Data types and models
│   ├── WebSocketClient.cs  # WebSocket communication
│   ├── FileManager.cs      # File I/O operations
│   ├── Upload.cs           # Upload manager
│   ├── Download.cs         # Download manager
│   ├── Verification.cs     # File integrity verification
│   └── Performance.cs      # Performance monitoring
├── AudioStreamCache.csproj
├── build.sh                # Unix build script
├── build.ps1               # Windows build script
├── run-client.sh           # Unix run script
├── run-client.ps1          # Windows run script
└── README.md
```

## Core Components

- **CliParser**: Parses command-line arguments
- **Logger**: Provides formatted logging with timestamps
- **WebSocketClient**: Manages WebSocket connection and message exchange
- **FileManager**: Handles file I/O and SHA-256 computation
- **Upload**: Coordinates file upload workflow
- **Download**: Coordinates file download workflow
- **Verification**: Verifies file integrity after streaming
- **PerformanceMonitor**: Tracks timing and calculates throughput

## mmap Implementation

In C#, memory-mapped files are implemented using the built-in `System.IO.MemoryMappedFiles` namespace, which provides a safe and cross-platform way to map files into memory. This allows for efficient file I/O operations, especially for large audio files.

### Key Benefits of mmap in C#:

- **Zero-copy I/O**: Data is read/written directly from/to memory without intermediate copies
- **Efficient for Large Files**: Maps only portions of files that are actually accessed
- **Improved Performance**: Leverages OS-level caching and memory management
- **Safe API**: .NET's type safety prevents common mmap errors
- **Simplified Access**: Read/write operations using familiar .NET types
- **Cross-platform**: Works on Windows, Linux, macOS, and other .NET-supported platforms
- **Built-in Support**: No external dependencies required

### Usage Example:

```csharp
using System.IO.MemoryMappedFiles;
using System.IO;

// Create or open a memory-mapped file
using var mmf = MemoryMappedFile.CreateFromFile(
    "audio.mp3",
    FileMode.Open,
    null,
    0,
    MemoryMappedFileAccess.Read
);

// Create a view accessor for reading
using var accessor = mmf.CreateViewAccessor(
    0,
    0,
    MemoryMappedFileAccess.Read
);

// Read data directly from memory
const int chunkSize = 65536; // 64KB
byte[] buffer = new byte[chunkSize];
long offset = 0;

// Read chunks until end of file
while (accessor.ReadArray(offset, buffer, 0, chunkSize) > 0)
{
    // Process chunk data
    ProcessChunk(buffer);
    offset += chunkSize;
}
```

### Alternative: MemoryMappedViewStream

For stream-based access to memory-mapped files:

```csharp
using (var mmf = MemoryMappedFile.CreateFromFile("audio.mp3", FileMode.Open))
using (var stream = mmf.CreateViewStream(0, 0, MemoryMappedFileAccess.Read))
using (var reader = new BinaryReader(stream))
{
    // Read data as a stream
    byte[] buffer = new byte[65536];
    int bytesRead;
    while ((bytesRead = reader.Read(buffer, 0, buffer.Length)) > 0)
    {
        // Process chunk data
        ProcessChunk(buffer.AsSpan(0, bytesRead));
    }
}
```

## Building

### Unix/Linux/macOS

```bash
./build.sh
```

### Windows (PowerShell)

```powershell
.\build.ps1
```

## Running

### Basic Usage

```bash
# Unix/Linux/macOS
./run-client.sh --input audio/input/hello.mp3

# Windows (PowerShell)
.\run-client.ps1 --input audio/input/hello.mp3
```

### Command-Line Options

```
--input <path>     Input audio file path (required)
--output <path>    Output audio file path (optional, default: audio/output/output-{timestamp}-{filename})
--server <uri>     WebSocket server URI (optional, default: ws://localhost:8080/audio)
--verbose, -v      Enable verbose logging
--help, -h         Show help message
```

### Examples

```bash
# Basic usage with default server
./run-client.sh --input audio/input/hello.mp3

# Custom server
./run-client.sh --input audio/input/hello.mp3 --server ws://192.168.1.100:8080/audio

# Custom output path
./run-client.sh --input audio/input/hello.mp3 --output /tmp/output.mp3

# Verbose mode
./run-client.sh --input audio/input/hello.mp3 --verbose
```

## Configuration

- **Chunk Size**: 8KB (8192 bytes) - matches server behavior
- **WebSocket Protocol**: JSON control messages + binary data frames
- **Checksum Algorithm**: SHA-256
- **Performance Targets**: Upload >100 Mbps, Download >200 Mbps

## Output Format

The client outputs structured logs with timestamps:

```
[2026-01-24 10:30:15.123] [info] Audio Stream Cache Client - C# Implementation
[2026-01-24 10:30:15.124] [info] Server URI: ws://localhost:8080/audio
[2026-01-24 10:30:15.125] [info] Input file: audio/input/hello.mp3
[2026-01-24 10:30:15.126] [info] Output file: audio/output/output-20260124-103015-hello.mp3
[2026-01-24 10:30:15.127] [info] Input file size: 92124 bytes

=== Connecting to Server ===
[2026-01-24 10:30:15.234] [info] Successfully connected to server

=== Starting Upload ===
[2026-01-24 10:30:15.345] [info] Generated stream ID: stream-20260124-103015-a1b2c3d4
[2026-01-24 10:30:15.456] [info] Upload progress: 23031/92124 bytes (25%)
[2026-01-24 10:30:15.567] [info] Upload progress: 46062/92124 bytes (50%)
[2026-01-24 10:30:15.678] [info] Upload progress: 69093/92124 bytes (75%)
[2026-01-24 10:30:15.789] [info] Upload progress: 92124/92124 bytes (100%)
[2026-01-24 10:30:15.890] [info] Upload completed successfully with stream ID: stream-20260124-103015-a1b2c3d4

=== Starting Download ===
[2026-01-24 10:30:16.001] [info] Download progress: 23031/92124 bytes (25%)
[2026-01-24 10:30:16.112] [info] Download progress: 46062/92124 bytes (50%)
[2026-01-24 10:30:16.223] [info] Download progress: 69093/92124 bytes (75%)
[2026-01-24 10:30:16.334] [info] Download progress: 92124/92124 bytes (100%)
[2026-01-24 10:30:16.445] [info] Download completed successfully

=== Verifying File Integrity ===
[2026-01-24 10:30:16.556] [info] ✓ File verification PASSED - Files are identical

=== Performance Report ===
[2026-01-24 10:30:16.667] [info] Upload Duration: 554 ms
[2026-01-24 10:30:16.668] [info] Upload Throughput: 1.33 Mbps
[2026-01-24 10:30:16.669] [info] Download Duration: 444 ms
[2026-01-24 10:30:16.670] [info] Download Throughput: 1.66 Mbps
[2026-01-24 10:30:16.671] [info] Total Duration: 998 ms
[2026-01-24 10:30:16.672] [info] Average Throughput: 1.48 Mbps

=== Workflow Complete ===
[2026-01-24 10:30:16.778] [info] Successfully uploaded, downloaded, and verified file: audio/input/hello.mp3
```

## Memory-Mapped File Best Practices

1. **Use Appropriate Access Modes**: Choose between read-only, write-only, or read-write access based on your needs
2. **Dispose Resources Properly**: Always use `using` statements or explicitly call `Dispose()` on memory-mapped file objects
3. **Handle Large Files**: For files larger than 2GB, use 64-bit view accessors
4. **Consider Memory Pressure**: Large memory-mapped files can increase memory pressure on the garbage collector
5. **Synchronization**: Use proper synchronization when multiple threads access the same memory-mapped file
6. **Error Handling**: Catch and handle exceptions related to file access and memory mapping
7. **File Locking**: Be aware of file locking behavior when using memory-mapped files

## Modern C# Features Used

- **Records**: Immutable data types for stream results
- **Async/Await**: Asynchronous programming model
- **Span<T> and Memory<T>**: Efficient memory operations
- **Nullable Reference Types**: Improved type safety
- **Top-level Statements**: Simplified program entry points
- **Pattern Matching**: Enhanced switch statements and expressions
- **String Interpolation**: Type-safe string formatting
- **Local Functions**: Encapsulated helper functions

## Cross-platform Considerations

- **File Paths**: Use `Path.Combine()` and `Path.DirectorySeparatorChar` for cross-platform path handling
- **Line Endings**: Be aware of platform-specific line endings when logging or processing text data
- **Encoding**: Specify encodings explicitly to avoid platform-dependent defaults
- **System Calls**: Avoid platform-specific system calls when possible
- **Testing**: Test on all target platforms to ensure compatibility

## Deployment

```bash
# Publish for Windows
dotnet publish --runtime win-x64 --self-contained

# Publish for Linux
dotnet publish --runtime linux-x64 --self-contained

# Publish for macOS
dotnet publish --runtime osx-x64 --self-contained

# Publish as framework-dependent (smaller output)
dotnet publish --runtime linux-x64 --no-self-contained
```

## Performance Benchmarks

To run performance benchmarks using BenchmarkDotNet:

```bash
dotnet run --project AudioStreamCache.Benchmarks --configuration Release
```

Example benchmark results:

```
| Method | FileSize | Mean | Error | StdDev | Throughput |
|------- |--------- |----- |------ |------- |----------- |
| Upload | 100MB | 1.23s | 0.02s | 0.01s | 81.3MB/s |
| Download | 100MB | 1.18s | 0.01s | 0.01s | 84.7MB/s |
| UploadWithMmap | 100MB | 0.98s | 0.02s | 0.02s | 102.0MB/s |
| DownloadWithMmap | 100MB | 0.95s | 0.01s | 0.01s | 105.3MB/s |
```

## Safety Considerations

- **Resource Management**: Always dispose memory-mapped file objects to avoid resource leaks
- **File Access**: Ensure proper file permissions when creating or accessing memory-mapped files
- **Security**: Be cautious when mapping files from untrusted sources
- **Memory Usage**: Monitor memory usage for large streams
- **Exception Handling**: Implement comprehensive exception handling for all file and network operations
- **Thread Safety**: Use proper synchronization for shared resources