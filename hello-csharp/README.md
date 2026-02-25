# Audio Stream Cache — C# Implementation

基于 WebSocket + mmap 的高性能音频流服务（C# 实现）。

## 功能特性

- **WebSocket 流服务**：HttpListener + System.Net.WebSockets 原生 WebSocket
- **mmap 存储**：MemoryMappedFile 内存映射文件缓存
- **async/await 异步**：高效并发连接处理
- **状态管理**：完整的流状态转换（UPLOADING → READY → ERROR）
- **资源保护**：30 秒自动清理过期流，最大 1000 流
- **MD5 校验**：客户端上传/下载完整性验证

## 技术栈

- .NET 9.0
- System.Net.WebSockets（内置）
- System.IO.MemoryMappedFiles（内置）
- System.Text.Json（内置）

## 项目结构

```
hello-csharp/
├── src/
│   ├── Program.cs                 # 统一入口（server / client）
│   ├── Server/
│   │   ├── Server.cs              # WebSocket 服务器
│   │   ├── StreamManager.cs       # 流管理器
│   │   ├── MmapCache.cs           # mmap 缓存
│   │   ├── Handler.cs             # 连接处理器
│   │   ├── Message.cs             # JSON 消息
│   │   └── Protocol.cs            # 协议枚举
│   └── Client/
│       └── Client.cs              # WebSocket 客户端
├── scripts/                       # 构建 & 运行脚本
└── AudioStreamCache.csproj
```

## 快速开始

### 构建

```bash
dotnet build -c Release
```

### 运行服务端

```bash
dotnet run -- server --port 8080

# 或使用脚本
./scripts/run-server.sh
.\scripts\run-server.ps1
```

### 运行客户端

```bash
dotnet run -- client --server ws://localhost:8080 --input ../audio/input/hello.opus

# 或使用脚本
./scripts/run-client.sh
.\scripts\run-client.ps1
```

## 消息协议

参见 [hello-java/README.md](../hello-java/README.md#消息协议) 获取完整协议说明。
