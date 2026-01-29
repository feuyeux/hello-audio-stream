# Audio Stream - Rust Implementation

高性能音频流传输系统，使用内存映射文件 I/O（mmap）实现高效的 WebSocket 文件传输。

## 快速开始

### 前置要求

- Rust 1.70+
- Cargo（Rust 包管理器）

### 构建和运行

本项目提供了跨平台的构建和运行脚本，位于 `scripts/` 目录：

#### Windows (PowerShell)

```powershell
# 构建客户端
.\scripts\build-client.ps1

# 运行客户端
.\scripts\run-client.ps1

# 构建服务端
.\scripts\build-server.ps1

# 运行服务端
.\scripts\run-server.ps1
```

#### Unix/Linux/macOS (Bash)

```bash
# 构建客户端
./scripts/build-client.sh

# 运行客户端
./scripts/run-client.sh

# 构建服务端
./scripts/build-server.sh

# 运行服务端
./scripts/run-server.sh
```

### 手动构建

```bash
# 构建 Debug 版本
cargo build

# 构建 Release 版本
cargo build --release
```

### 运行二进制文件

```bash
# 运行客户端（Debug）
cargo run --bin audio_stream_client

# 运行服务端（Debug）
cargo run --bin audio_stream_server

# 运行客户端（Release）
./target/release/audio_stream_client

# 运行服务端（Release）
./target/release/audio_stream_server
```

### RustRover

```sh
# server
run --package audio-stream --bin audio_stream_server
# client
run --package audio-stream --bin audio_stream_client -- --server ws://localhost:8080/audio --input ..\audio\input\hello.mp3
```
