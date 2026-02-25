# Audio Stream Cache — Rust Implementation

基于 WebSocket + mmap 的高性能音频流服务（Rust 实现）。

## 功能特性

- **WebSocket 流服务**：tokio-tungstenite 异步 WebSocket
- **mmap 存储**：memmap2 内存映射文件缓存
- **Tokio 异步运行时**：高效并发连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **SHA-256 校验**：客户端上传/下载完整性验证

## 技术栈

- Rust 1.70+
- tokio + tokio-tungstenite
- serde + serde_json
- memmap2
- clap (CLI)

## 项目结构

```
hello-rust/
├── src/
│   ├── lib.rs
│   ├── bin/
│   │   ├── server.rs              # 服务端入口
│   │   └── client.rs              # 客户端入口
│   ├── server/
│   │   ├── mod.rs
│   │   ├── server.rs              # WebSocket 服务器
│   │   ├── stream_manager.rs      # 流管理器
│   │   ├── mmap_cache.rs          # mmap 缓存
│   │   ├── handler.rs             # 连接处理器
│   │   ├── message.rs             # JSON 消息
│   │   └── protocol.rs            # 协议枚举
│   └── client/
│       └── mod.rs                 # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── Cargo.toml
```

## 快速开始

### 构建

```bash
cargo build --release
```

### 运行服务端

```bash
./target/release/server --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
./target/release/client --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
