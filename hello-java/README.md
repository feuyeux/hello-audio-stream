# Audio Stream Cache

基于 WebSocket + mmap 的高性能音频流服务。

## 功能特性

- **WebSocket流服务**：长连接双向流
- **mmap存储**：高性能内存映射文件缓存
- **虚拟线程**：JDK 25 虚拟线程处理并发

## 技术栈

- Java 25 (--enable-preview)
- Netty 4.2
- Java-WebSocket
- SLF4J + Logback
- Maven

## 快速开始

### 编译

```bash
cd hello-java
mvn clean package -DskipTests
```

### 运行服务端

```bash
cd audio-stream-server
java --enable-preview -jar target/audio-stream-server-1.0.0.jar
```

或使用脚本：

```bash
# Windows
.\scripts\run-server.ps1

# Linux/macOS
./scripts/run-server.sh
```

### 运行客户端

```bash
cd audio-stream-client
java --enable-preview -jar target/audio-stream-client-1.0.0.jar --input <audio-file>
```

## 消息协议

### 客户端 → 服务端

| 类型 | 格式 | 示例 |
|:------|:------|:------|
| START | `{"type":"START","streamId":"xxx"}` | 开启流 |
| DATA | 二进制数据 | 音频数据 |
| GET | `{"type":"GET","streamId":"xxx","offset":0,"length":65536}` | 获取数据 |
| STOP | `{"type":"STOP"}` | 关闭流 |

### 服务端 → 客户端

| 类型 | 格式 | 示例 |
|:------|:------|:------|
| CONNECTED | `{"type":"CONNECTED","streamId":"xxx"}` | 连接确认 |
| STARTED | `{"type":"STARTED","streamId":"xxx"}` | 流创建成功 |
| DATA | 二进制数据 | 返回音频数据 |
| ERROR | `{"type":"ERROR","message":"xxx"}` | 错误信息 |

## 配置

| 参数 | 默认值 | 说明 |
|:------|:--------|:------|
| `ws.path` | /audio | WebSocket路径 |
| `cache.dir` | cache | 缓存目录 |
| server.port | 8080 | 监听端口 |

## JDK 25 特性

- 虚拟线程 (Virtual Threads)
- Record 类
- 模式匹配

## License

MIT
