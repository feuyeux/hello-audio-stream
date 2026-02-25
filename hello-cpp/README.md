# Audio Stream Cache — C++ Implementation

基于 WebSocket + mmap 的高性能音频流服务（C++ 实现）。

## 功能特性

- **WebSocket 流服务**：WebSocket++ (ASIO) 异步 WebSocket
- **mmap 存储**：平台原生 mmap/MapViewOfFile 内存映射文件缓存
- **ASIO 异步 I/O**：高效并发连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- C++17 / CMake 3.20+
- WebSocket++ + ASIO（头文件库）
- nlohmann/json
- spdlog（日志）
- 本地依赖（`lib/` 目录，无需网络下载）

## 项目结构

```
hello-cpp/
├── include/
│   ├── server/
│   │   ├── server.h               # WebSocket 服务器
│   │   ├── stream_manager.h       # 流管理器
│   │   ├── mmap_cache.h           # mmap 缓存
│   │   ├── handler.h              # 连接处理器
│   │   ├── message.h              # JSON 消息
│   │   └── protocol.h             # 协议枚举
│   └── client/
│       └── client.h               # WebSocket 客户端
├── src/
│   ├── server/
│   │   ├── server.cpp
│   │   ├── stream_manager.cpp
│   │   ├── mmap_cache.cpp
│   │   ├── handler.cpp
│   │   └── CMakeLists.txt
│   └── client/
│       ├── client.cpp
│       └── CMakeLists.txt
├── lib/                           # 本地依赖库
│   ├── asio/
│   ├── websocketpp/
│   ├── nlohmann_json/
│   ├── spdlog/
│   ├── googletest/
│   └── rapidcheck/
├── scripts/                       # 构建 & 运行脚本
└── CMakeLists.txt
```

## 快速开始

### 构建

```bash
cd build
cmake ..
cmake --build . --config Release
```

### 运行服务端

```bash
./build/bin/Release/audio_stream_server 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
./build/bin/Release/audio_stream_client ws://localhost:8080 ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
