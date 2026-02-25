# Audio Stream Cache — Dart Implementation

基于 WebSocket + mmap 的高性能音频流服务（Dart 实现）。

## 功能特性

- **WebSocket 流服务**：shelf_web_socket（服务端）+ web_socket_channel（客户端）
- **mmap 存储**：RandomAccessFile 内存映射文件缓存
- **async/await 异步**：Dart 异步模型高效连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- Dart 3.0+
- shelf + shelf_web_socket
- web_socket_channel
- crypto（MD5）
- args（CLI）

## 项目结构

```
hello-dart/
├── lib/
│   ├── server/
│   │   ├── server.dart            # WebSocket 服务器
│   │   ├── stream_manager.dart    # 流管理器
│   │   ├── mmap_cache.dart        # mmap 缓存
│   │   ├── handler.dart           # 连接处理器
│   │   ├── message.dart           # JSON 消息
│   │   └── protocol.dart          # 协议枚举
│   └── client/
│       └── client.dart            # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── pubspec.yaml
```

## 快速开始

### 安装依赖

```bash
dart pub get
```

### 编译

```bash
dart compile exe lib/server/server.dart -o audio/audio_stream_server.exe
dart compile exe lib/client/client.dart -o audio/audio_stream_client.exe
```

### 运行服务端

```bash
dart run lib/server/server.dart --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
dart run lib/client/client.dart --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
