# Audio File Transfer - Java Implementation

This directory contains a Java implementation of an audio file transfer utility that supports both upload and download operations using WebSocket communication.

## Features

- **Bi-directional Transfer**: Support for both uploading and downloading audio files
- **Chunked Transfer**: Files are transferred in chunks (default 64KB) for efficient processing
- **WebSocket Communication**: Reusable WebSocket connection for low-latency streaming
- **Automatic Reconnection**: Built-in retry mechanism for failed connections
- **Error Handling**: Comprehensive error handling with retry logic
- **Performance Metrics**: Detailed transfer statistics including throughput
- **Modern Java Features**: Uses JDK 25 features like records and pattern matching

## Technical Stack

- **Language**: Java 25
- **WebSocket Library**: Java-WebSocket (org.java-websocket:Java-WebSocket)
- **Logging**: SLF4J with Logback
- **Concurrency**: Virtual Threads (JDK 21+ feature)
- **Build System**: Maven
- **Testing**: JUnit 5

## Build and Run

This is a multi-module Maven project with client and server modules. Use the provided build scripts for each platform.

### Windows

```bash
cd audio-stream-server
.\build-server.ps1
.\run-server.ps1

cd audio-stream-client
.\build-client.ps1
.\run-client.ps1
```

### Linux/macOS

```bash
cd audio-stream-server
./build-server.sh
./run-server.sh

cd audio-stream-client
./build-client.sh
./run-client.sh
```

### Using Maven directly

```bash
# Build all modules from root
mvn clean install -DskipTests

# Build server only
cd audio-stream-server
mvn clean package -DskipTests
java --enable-preview -jar target/audio-stream-server-1.0.0.jar

# Build client only
cd audio-stream-client
mvn clean package -DskipTests
java --enable-preview -jar target/audio-stream-client-1.0.0.jar
```

**Note**: This project requires JDK 25 and uses preview features. The `--enable-preview` flag is required when running the application.

## Testing

```bash
# Run unit tests
mvn test

# Run integration tests
mvn verify
```