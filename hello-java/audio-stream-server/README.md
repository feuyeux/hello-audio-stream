# Audio Stream Server

高性能WebSocket音频流缓存服务器，使用mmap和虚拟线程技术。

## 功能特性

- **WebSocket服务**：基于Netty的高性能WebSocket服务器
- **内存映射缓存**：使用mmap技术进行文件缓存，提高I/O性能
- **虚拟线程**：使用JDK 25虚拟线程处理并发请求
- **背压控制**：防止内存溢出，保护系统稳定性
- **消息处理**：支持上传、下载、查询等多种消息类型
- **内存池**：高效管理内存资源

## 技术栈

- Java 25（使用--enable-preview特性）
- Netty 4.1.115.Final
- SLF4J 2.0.16 + Logback 1.5.12
- Maven

## 项目结构

```
audio-stream-server/
├── src/main/java/org/feuyeux/mmap/audio/server/
│   ├── cache/                          # 缓存管理
│   │   └── MmapCacheManager.java      # mmap缓存管理器
│   ├── handler/                        # 消息处理
│   │   └── WebSocketMessageHandler.java  # WebSocket消息处理器
│   ├── memory/                         # 内存管理
│   │   ├── BackpressureController.java # 背压控制器
│   │   ├── MemoryPool.java            # 内存池
│   │   └── VirtualThreadExecutor.java # 虚拟线程执行器
│   ├── network/                        # 网络层
│   │   └── AudioWebSocketServer.java   # WebSocket服务器
│   └── AudioServerApplication.java     # 主应用入口
├── src/main/resources/
│   └── logback.xml                     # 日志配置
├── docs/                              # 文档目录
│   ├── architecture.drawio             # 架构图
│   ├── principle.drawio                # 原理图
│   └── verification.drawio             # 验证流程图
├── cache/                              # 缓存目录
└── logs/                              # 日志目录
```

## 快速开始

### 前置要求

- Java 25或更高版本
- Maven 3.8+

### 编译项目

```bash
cd audio-stream-server
mvn clean package
```

或在Windows上：

```cmd
build-server.bat
```

### 运行服务器

```bash
java --enable-preview -jar target/audio-stream-server-1.0.0.jar
```

或使用启动脚本：

```cmd
start-server.bat
```

### 默认配置

- 监听端口：`8080`
- WebSocket路径：`/audio`
- 缓存目录：`cache/`

## 系统架构

### 核心组件

1. **AudioWebSocketServer**：Netty WebSocket服务器，负责接受连接
2. **WebSocketMessageHandler**：处理WebSocket消息，协调缓存和内存管理
3. **MmapCacheManager**：使用mmap技术缓存音频数据
4. **BackpressureController**：背压控制，防止内存溢出
5. **MemoryPool**：内存池，高效管理内存资源
6. **VirtualThreadExecutor**：虚拟线程执行器，处理并发任务

### 数据流

```
Client -> WebSocket -> MessageHandler -> CacheManager -> Mmap Cache
Client <- WebSocket <- MessageHandler <- CacheManager <- Mmap Cache
```

## 消息协议

### 消息类型

1. **START消息**：开始上传
    - 格式：`START:{streamId}`
    - 示例：`START:stream-abc123`

2. **DATA消息**：音频数据
    - 格式：二进制数据

3. **GET消息**：获取数据
    - 格式：`GET:{streamId}:{offset}:{length}`
    - 示例：`GET:stream-abc123:0:8192`

4. **STOP消息**：停止上传
    - 格式：`STOP:{streamId}`
    - 示例：`STOP:stream-abc123`

5. **DELETE消息**：删除缓存
    - 格式：`DELETE:{streamId}`
    - 示例：`DELETE:stream-abc123`

### 响应格式

- 成功：二进制音频数据
- 错误：`ERROR:{error message}`

## 核心特性

### 1. 内存映射缓存

使用Java NIO的mmap技术将文件映射到内存，提供高性能的文件访问：

```java
MappedByteBuffer buffer = channel.map(
        FileChannel.MapMode.READ_WRITE,
        0,
        fileSize
);
```

优势：

- 减少内存拷贝
- 利用操作系统页面缓存
- 支持大文件处理

### 2. 虚拟线程

使用JDK 25虚拟线程处理并发请求：

```java
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
executor.

submit(() ->

handleRequest());
```

优势：

- 轻量级线程创建
- 高并发处理能力
- 阻塞操作不影响性能

### 3. 背压控制

当内存使用超过阈值时，自动限制新请求：

- 监控内存使用率
- 动态调整并发数
- 优先处理现有请求
- 平滑拒绝新请求

### 4. 内存池

预先分配内存块，避免频繁的内存分配和垃圾回收：

```java
MemoryPool pool = new MemoryPool(poolSize, chunkSize);
ByteBuffer buffer = pool.allocate();
pool.

release(buffer);
```

优势：

- 减少GC压力
- 提高内存利用率
- 支持批量操作

## 配置说明

### 系统参数

| 参数                     | 默认值    | 说明          |
|------------------------|--------|-------------|
| server.port            | 8080   | 服务器监听端口     |
| server.path            | /audio | WebSocket路径 |
| cache.directory        | cache/ | 缓存目录        |
| memory.pool.size       | 100    | 内存池大小       |
| memory.chunk.size      | 8192   | 内存块大小       |
| backpressure.threshold | 0.8    | 背压阈值（内存使用率） |

### 日志配置

日志配置文件位于`src/main/resources/logback.xml`，支持：

- 控制台输出
- 文件输出（自动滚动）
- 日志级别配置
- 日志格式统一

日志文件位置：`logs/audio-stream.log`

## 性能优化

### 内存优化

- 使用mmap减少内存拷贝
- 内存池减少GC压力
- 背压控制防止内存溢出

### 并发优化

- 虚拟线程提高并发处理能力
- Netty事件循环模型
- 异步非阻塞I/O

### I/O优化

- 零拷贝技术
- 批量数据传输
- 操作系统页面缓存

## 监控指标

### 关键指标

- 当前连接数
- 缓存文件数量
- 总缓存大小
- 内存使用率
- 请求处理时间
- 吞吐量（MB/s）

### 日志级别

- DEBUG：详细调试信息
- INFO：一般信息
- WARN：警告信息
- ERROR：错误信息

## 故障排查

### 端口冲突

如果端口被占用，修改监听端口：

```java
AudioWebSocketServer server = new AudioWebSocketServer(8081);
```

### 内存溢出

如果遇到内存溢出：

1. 调整JVM堆大小：`-Xmx2g`
2. 调整背压阈值：减小阈值
3. 限制并发数：减少虚拟线程数量

### 性能问题

如果性能不佳：

1. 增加内存池大小
2. 调整chunk大小
3. 检查磁盘I/O性能
4. 监控GC情况

## 开发

### 运行测试

```bash
mvn test
```

### 调试模式

启动时添加调试参数：

```bash
java --enable-preview -jar target/audio-stream-server-1.0.0.jar --debug
```

### 添加新功能

1. 在相应的包中添加新类
2. 更新消息协议（如果需要）
3. 添加测试用例
4. 更新文档

## JDK 25特性

本项目使用以下JDK 25新特性：

1. **虚拟线程**：处理并发请求
2. **Record类**：定义数据传输对象
3. **模式匹配**：简化条件逻辑
4. **字符串模板**：格式化字符串（需要--enable-preview）

## 安全措施

- 输入参数验证
- 文件大小限制
- 连接超时控制
- 错误处理和恢复

## 示例场景

### 场景1：上传音频文件

1. 客户端发送`START:stream-123`
2. 服务器创建mmap缓存文件
3. 客户端分批发送音频数据
4. 服务器写入mmap缓存
5. 客户端发送`STOP:stream-123`

### 场景2：下载音频文件

1. 客户端发送`GET:stream-123:0:8192`
2. 服务器从mmap缓存读取数据
3. 服务器返回二进制数据
4. 客户端继续请求后续数据

### 场景3：删除缓存

1. 客户端发送`DELETE:stream-123`
2. 服务器删除mmap缓存文件
3. 服务器释放内存资源

## 扩展性

- 支持多实例部署
- 支持分布式缓存
- 支持持久化存储
- 支持集群模式

## 许可证

本项目仅供学习和研究使用。

## 联系方式

如有问题或建议，请提交Issue。
