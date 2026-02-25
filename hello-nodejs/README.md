# Audio Stream Cache — Node.js Implementation

基于 WebSocket + mmap 的高性能音频流服务（Node.js 实现）。

## 功能特性

- **WebSocket 流服务**：ws 库实现高性能 WebSocket 通信
- **mmap 存储**：mmap-io 内存映射文件缓存
- **异步处理**：ES Module + async/await 异步连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **SHA-256 校验**：客户端上传/下载完整性验证

## 技术栈

- Node.js 18+（ES Module）
- ws（WebSocket）
- mmap-io
- commander（CLI）

## 项目结构

```
hello-nodejs/
├── src/
│   ├── server.js                  # 服务端入口
│   ├── client.js                  # 客户端入口
│   ├── server/
│   │   ├── server.js              # WebSocket 服务器
│   │   ├── streamManager.js       # 流管理器
│   │   ├── mmapCache.js           # mmap 缓存
│   │   ├── handler.js             # 连接处理器
│   │   ├── message.js             # JSON 消息
│   │   └── protocol.js            # 协议枚举
│   └── client/
│       └── client.js              # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── package.json
```

## 快速开始

### 安装依赖

```bash
npm install
```

### 运行服务端

```bash
node src/server.js --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
node src/client.js --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
