# Audio Stream Cache — PHP Implementation

基于 WebSocket + mmap 的高性能音频流服务（PHP 实现）。

## 功能特性

- **WebSocket 流服务**：Ratchet（服务端）+ TextAlk WebSocket（客户端）
- **mmap 存储**：shmop 共享内存缓存
- **ReactPHP 事件循环**：异步非阻塞连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- PHP 8.3+
- Ratchet（WebSocket 服务端）
- textalk/websocket（WebSocket 客户端）
- Composer

## 项目结构

```
hello-php/
├── audio_stream_server.php        # 服务端入口
├── audio_stream_client.php        # 客户端入口
├── src/
│   ├── Server/
│   │   ├── Server.php             # WebSocket 服务器
│   │   ├── StreamManager.php      # 流管理器
│   │   ├── MmapCache.php          # mmap 缓存
│   │   ├── Handler.php            # 连接处理器
│   │   ├── Message.php            # JSON 消息
│   │   └── Protocol.php           # 协议枚举
│   └── Client/
│       └── Client.php             # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── composer.json
```

## 快速开始

### 安装依赖

```bash
composer install
```

### 运行服务端

```bash
php audio_stream_server.php --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
php audio_stream_client.php --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
