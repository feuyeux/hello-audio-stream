# Audio Stream Cache — Kotlin Implementation

基于 WebSocket + mmap 的高性能音频流服务（Kotlin 实现）。

## 功能特性

- **WebSocket 流服务**：Ktor WebSocket 服务端/客户端
- **mmap 存储**：MappedByteBuffer 内存映射文件缓存
- **协程并发**：Kotlin Coroutines 高效连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- JDK 21+
- Kotlin 2.0+ / Kotlin Coroutines
- Ktor 3.0（Netty 引擎）
- kotlinx.serialization
- Gradle (Kotlin DSL)

## 项目结构

```
hello-kotlin/
├── src/main/kotlin/
│   ├── Main.kt                    # 统一入口（server / client）
│   ├── server/
│   │   ├── Server.kt              # WebSocket 服务器
│   │   ├── StreamManager.kt       # 流管理器
│   │   ├── MmapCache.kt           # mmap 缓存
│   │   ├── Handler.kt             # 连接处理器
│   │   ├── Message.kt             # JSON 消息
│   │   └── Protocol.kt            # 协议枚举
│   └── client/
│       └── Client.kt              # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
├── build.gradle.kts
└── settings.gradle.kts
```

## 快速开始

### 构建

```bash
gradle build
```

### 运行服务端

```bash
gradle runServer --args="--port 8080"

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
gradle runClient --args="--server ws://localhost:8080 --input ../audio/input/hello.opus"

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
