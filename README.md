# Hello Audio Stream - mmap 实现编译运行指南

本项目实现了 12 种语言的音频流传输系统，使用内存映射文件 (mmap) 进行高效缓存。

## 端到端测试流程

1. 启动任意语言的服务端（监听 8080 端口）
2. 运行任意语言的客户端上传音频文件
3. 客户端从服务端下载文件
4. 验证文件完整性（SHA-256）

---

## 编译与运行

### C++ (hello-cpp)

**编译:**
```bash
cd hello-cpp
./build.sh
```

**运行服务端:**
```bash
./run-server.sh
```

**运行客户端:**
```bash
./run-client.sh ws://localhost:8080/audio ../audio/input/hello.mp3
```

**mmap 实现:** 原生 POSIX (`sys/mman.h`) / Windows API，分段映射 1GB

---

### Rust (hello-rust)

**编译:**
```bash
cd hello-rust
./scripts/build-server.sh
```

**运行服务端:**
```bash
./scripts/run-server.sh
```

**运行客户端:**
```bash
./scripts/run-client.sh
```

**mmap 实现:** `memmap2` crate，`MmapMut` 可变内存映射

---

### Java (hello-java)

**编译:**
```bash
cd hello-java/audio-stream-server
mvn clean package -DskipTests
```

**运行服务端:**
```bash
java --enable-preview -jar target/audio-stream-server-1.0.0.jar
```

**运行客户端:**
```bash
cd ../audio-stream-client
mvn clean package -DskipTests
java --enable-preview -jar target/audio-stream-client-1.0.0.jar --input ../../audio/input/hello.mp3
```

**mmap 实现:** `java.nio.MappedByteBuffer`，1GB 分段映射

---

### Kotlin (hello-kotlin)

**编译:**
```bash
cd hello-kotlin
./build.sh
```

**运行服务端:**
```bash
cd server
./run-server.sh
```

**运行客户端:**
```bash
cd ../client
./run-client.sh --input ../../audio/input/hello.mp3
```

**mmap 实现:** Java 的 `MappedByteBuffer` 通过 JNA

---

### Python (hello-python)

**安装依赖:**
```bash
cd hello-python
./build.sh
```

**运行服务端:**
```bash
source venv/bin/activate
python -m audio_server.audio_server_application
```

**运行客户端:**
```bash
source venv/bin/activate
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** 标准库 `mmap.mmap`，动态调整映射大小

---

### Go (hello-go)

**编译:**
```bash
cd hello-go
go build ./...
```

**运行服务端:**
```bash
./bin/server
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** 使用 `os.File` 模拟（非原生 mmap，为 Windows 兼容）

---

### C# (hello-csharp)

**编译:**
```bash
cd hello-csharp
./build.sh
```

**运行服务端:**
```bash
./run-server.sh
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** `System.IO.MemoryMappedFiles` 命名空间

---

### Swift (hello-swift)

**编译:**
```bash
cd hello-swift
./build.sh
```

**运行服务端:**
```bash
./run-server.sh
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** Foundation `FileHandle`（文件操作而非真正的 mmap）

---

### Dart (hello-dart)

**编译:**
```bash
cd hello-dart
./build.sh
```

**运行服务端:**
```bash
./run-server.sh
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** `dart:io` `RandomAccessFile`

---

### Node.js (hello-nodejs)

**安装依赖:**
```bash
cd hello-nodejs
npm install
```

**运行服务端:**
```bash
node src/server.js
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** `mmap-io` npm 包

---

### TypeScript (hello-typescript)

**安装依赖:**
```bash
cd hello-typescript
npm install
npm run build
```

**运行服务端:**
```bash
node dist/server.js
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** 同 Node.js (`mmap-io`)

---

### PHP (hello-php)

**安装依赖:**
```bash
cd hello-php
./build.sh
```

**运行服务端:**
```bash
./run-server.sh
```

**运行客户端:**
```bash
./run-client.sh --input ../audio/input/hello.mp3
```

**mmap 实现:** 标准文件函数 `fopen/fread/fwrite`（非 mmap）

---

## 协议说明

### WebSocket 控制消息 (JSON)

```json
// 开始上传
{"type": "START", "streamId": "stream-123"}

// 上传完成
{"type": "STOP", "streamId": "stream-123"}

// 下载数据
{"type": "GET", "streamId": "stream-123", "offset": 0, "length": 65536}
```

### 数据帧

- 上传：二进制帧，8KB 分块
- 下载：二进制帧，64KB 分块

---

## mmap 实现分类

| 类型 | 语言 | 配置 |
|------|------|------|
| 原生 mmap | C++, Rust, Python | 8GB 缓存, 1GB 分段 |
| JVM/CLR mmap | Java, Kotlin, C# | 8GB 缓存, 1GB 分段 |
| 文件 I/O 模拟 | Go, Swift, Dart, Node.js, TypeScript, PHP | 8GB 缓存, 1GB 分段 |

所有实现均遵循统一规范 v2.0.0：
- **DEFAULT_PAGE_SIZE**: 64MB
- **MAX_CACHE_SIZE**: 8GB
- **SEGMENT_SIZE**: 1GB
- **BATCH_OPERATION_LIMIT**: 1000

详细技术文档请参考 [doc/mmap.md](doc/mmap.md)
