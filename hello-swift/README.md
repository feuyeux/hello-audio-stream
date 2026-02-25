# Audio Stream Cache — Swift Implementation

基于 WebSocket + mmap 的高性能音频流服务（Swift 实现）。

## 功能特性

- **WebSocket 流服务**：NIOWebSocket 原生 WebSocket 实现
- **mmap 存储**：mmap/munmap 系统调用内存映射文件缓存
- **Swift Concurrency**：async/await + actor 并发模型
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **SHA-1 校验**：客户端上传/下载完整性验证

## 技术栈

- Swift 6.0+
- SwiftNIO + NIOWebSocket
- Foundation（mmap/JSON）
- 无外部依赖（纯 Swift Package Manager）

## 项目结构

```
hello-swift/
├── Sources/
│   ├── Server/
│   │   ├── Server.swift           # WebSocket 服务器
│   │   ├── StreamManager.swift    # 流管理器
│   │   ├── MmapCache.swift        # mmap 缓存
│   │   ├── Handler.swift          # 连接处理器
│   │   ├── Message.swift          # JSON 消息
│   │   ├── Protocol.swift         # 协议枚举
│   │   ├── WebSocket.swift        # WebSocket 辅助
│   │   └── SHA1.swift             # SHA-1 工具
│   └── Client/
│       └── Client.swift           # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── Package.swift
```

## 快速开始

### 构建

```bash
swift build -c release
```

### 运行服务端

```bash
.build/release/Server --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
.build/release/Client --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
