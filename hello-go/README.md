# Audio Stream Cache — Go Implementation

基于 WebSocket + mmap 的高性能音频流服务（Go 实现）。

## 功能特性

- **WebSocket 流服务**：Gorilla WebSocket 长连接双向流
- **mmap 存储**：平台适配内存映射文件缓存（Windows CreateFileMapping / POSIX mmap）
- **Goroutine 并发**：轻量级协程处理多连接
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **SHA-256 校验**：客户端上传/下载完整性验证

## 技术栈

- Go 1.25
- gorilla/websocket
- cobra CLI

## 项目结构

```
hello-go/
├── cmd/
│   ├── server/                # 服务端入口 main.go
│   └── client/                # 客户端入口 main.go
├── src/
│   ├── server/
│   │   ├── server.go          # WebSocket 服务器
│   │   ├── stream_manager.go  # 流管理器（Stream + Config）
│   │   ├── mmap_cache.go      # mmap 缓存接口
│   │   ├── mmap_windows.go    # Windows mmap 实现
│   │   ├── mmap_unix.go       # POSIX mmap 实现
│   │   ├── handler.go         # 连接处理器
│   │   ├── message.go         # JSON 消息结构
│   │   └── protocol.go        # 协议枚举（CommandType, StreamCommand...）
│   └── client/
│       └── client.go          # WebSocket 客户端
├── scripts/                   # 构建 & 运行脚本
└── go.mod
```

## 快速开始

### 构建

```bash
go build -o bin/server ./cmd/server
go build -o bin/client ./cmd/client
```

### 运行服务端

```bash
./bin/server --port 8080

# 或使用脚本
./scripts/run-server.sh        # Linux/macOS
.\scripts\run-server.ps1       # Windows
```

### 运行客户端

```bash
./bin/client --server ws://localhost:8080/audio --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh        # Linux/macOS
.\scripts\run-client.ps1       # Windows
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
