# Audio Stream Cache — Python Implementation

基于 WebSocket + mmap 的高性能音频流服务（Python 实现）。

## 功能特性

- **WebSocket 流服务**：websockets 库实现异步 WebSocket 通信
- **mmap 存储**：标准库 mmap 内存映射文件缓存
- **asyncio 异步**：高效并发连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- Python 3.8+
- websockets >= 14.0
- mmap（标准库）

## 项目结构

```
hello-python/
├── src/
│   ├── server/
│   │   ├── __init__.py
│   │   ├── __main__.py            # 服务端入口
│   │   ├── server.py              # WebSocket 服务器
│   │   ├── stream_manager.py      # 流管理器
│   │   ├── mmap_cache.py          # mmap 缓存
│   │   ├── handler.py             # 连接处理器
│   │   ├── message.py             # JSON 消息
│   │   └── protocol.py            # 协议枚举
│   └── client/
│       ├── __init__.py
│       ├── __main__.py            # 客户端入口
│       └── client.py              # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
├── requirements.txt
├── pyproject.toml
└── setup.py
```

## 快速开始

### 安装依赖

```bash
pip install -r requirements.txt
# 或
pip install -e .
```

### 运行服务端

```bash
python -m server --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
python -m client --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
