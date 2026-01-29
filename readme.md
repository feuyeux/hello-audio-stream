# Memory-Mapped Cache

## 架构设计

### 组件层次

```
应用层 (Application)
    ↓
WebSocket Server
    ↓
StreamManager (流生命周期管理)
    ↓
MemoryMappedCache (每个流一个实例)
    ↓
操作系统 mmap API

独立组件: MemoryPoolManager (缓冲区复用)
```

### 组件职责

| 组件 | 职责 | 生命周期 |
|------|------|----------|
| **MemoryMappedCache** | 单个文件的内存映射操作 | 每个流一个实例 |
| **StreamContext** | 流的元数据和状态 | 由 StreamManager 管理 |
| **StreamManager** | 多个流的生命周期管理 | 实例化，应用级单例 |
| **MemoryPoolManager** | 临时缓冲区的复用管理 | 实例化，应用级单例 |

### 架构总览图

```mermaid
graph TB
    subgraph "应用层"
        APP[Application]
        WS[WebSocket Server]
    end
    
    subgraph "管理层"
        SM[StreamManager<br/>流生命周期管理]
        MPM[MemoryPoolManager<br/>缓冲区池管理]
    end
    
    subgraph "流上下文层"
        SC1[StreamContext<br/>stream-1]
        SC2[StreamContext<br/>stream-2]
        SCN[StreamContext<br/>stream-n]
    end
    
    subgraph "存储层"
        MMC1[MemoryMappedCache<br/>file-1.cache]
        MMC2[MemoryMappedCache<br/>file-2.cache]
        MMCN[MemoryMappedCache<br/>file-n.cache]
    end
    
    subgraph "操作系统层"
        OS[OS mmap API<br/>Windows/Linux/macOS]
    end
    
    APP --> WS
    WS --> SM
    WS --> MPM
    SM --> SC1
    SM --> SC2
    SM --> SCN
    SC1 --> MMC1
    SC2 --> MMC2
    SCN --> MMCN
    MMC1 --> OS
    MMC2 --> OS
    MMCN --> OS
    
    style APP fill:#e1f5ff
    style WS fill:#b3e5fc
    style SM fill:#81d4fa
    style MPM fill:#81d4fa
    style SC1 fill:#4fc3f7
    style SC2 fill:#4fc3f7
    style SCN fill:#4fc3f7
    style MMC1 fill:#29b6f6
    style MMC2 fill:#29b6f6
    style MMCN fill:#29b6f6
    style OS fill:#0288d1
```

### 核心组件类图

```mermaid
classDiagram
    class MemoryMappedCache {
        +SEGMENT_SIZE: 1GB
        +MAX_CACHE_SIZE: 8GB
        +BATCH_OPERATION_LIMIT: 1000
        -filePath: string
        -fileSize: uint64
        -isOpen: bool
        -rwMutex: ReadWriteLock
        -segments: Map~uint64, void*~
        +MemoryMappedCache(path)
        +create(initialSize): bool
        +open(): bool
        +close(): void
        +write(offset, data): int
        +read(offset, length): bytes
        +writeBatch(operations): int[]
        +readBatch(operations): bytes[]
        +resize(newSize): bool
        +finalize(finalSize): bool
        +flush(): bool
        +prefetch(offset, length): bool
        +evict(offset, length): bool
        +getSize(): uint64
        +getPath(): string
        +isOpen(): bool
        -mapSegment(segmentIndex): bool
        -unmapAllSegments(): void
    }
    
    class StreamContext {
        <<struct>>
        +streamId: string
        +cachePath: string
        +mmapFile: MemoryMappedCache
        +currentOffset: uint64
        +totalSize: uint64
        +createdAt: Timestamp
        +lastAccessedAt: Timestamp
        +status: StreamStatus
    }
    
    class StreamStatus {
        <<enumeration>>
        UPLOADING
        READY
        ERROR
    }
    
    class StreamManager {
        -cacheDir: string
        -streams: Map~string, StreamContext~
        -mutex: Mutex
        +StreamManager(cacheDirectory)
        +createStream(streamId): bool
        +getStream(streamId): StreamContext
        +deleteStream(streamId): bool
        +listActiveStreams(): string[]
        +writeChunk(streamId, data): bool
        +readChunk(streamId, offset, length): bytes
        +finalizeStream(streamId): bool
        +cleanupOldStreams(): void
        -getCachePath(streamId): string
    }
    
    class MemoryPoolManager {
        -bufferSize: int
        -poolSize: int
        -availableBuffers: Queue~Buffer~
        -mutex: Mutex
        +MemoryPoolManager(bufferSize, poolSize)
        +acquireBuffer(): Buffer
        +releaseBuffer(buffer): void
        +getAvailableBuffers(): int
        +getTotalBuffers(): int
    }
    
    StreamManager "1" --> "*" StreamContext: manages
    StreamContext "1" --> "1" MemoryMappedCache: owns
    StreamContext --> StreamStatus: uses
```

### 数据流程图

```mermaid
sequenceDiagram
    participant Client
    participant WS as WebSocket Server
    participant SM as StreamManager
    participant SC as StreamContext
    participant MMC as MemoryMappedCache
    participant MPM as MemoryPoolManager
    participant OS as OS mmap API
    
    Note over Client,OS: 应用启动
    WS->>SM: new StreamManager(cacheDir)
    WS->>MPM: new MemoryPoolManager(64KB, 100)
    
    Note over Client,OS: 创建流
    Client->>WS: upload request (streamId)
    WS->>SM: createStream(streamId)
    SM->>SC: new StreamContext
    SC->>MMC: new MemoryMappedCache(path)
    MMC->>OS: create file + mmap
    OS-->>MMC: file handle
    MMC-->>SC: cache instance
    SC-->>SM: context created
    SM-->>WS: success
    WS-->>Client: stream ready
    
    Note over Client,OS: 写入数据
    Client->>WS: send chunk
    WS->>MPM: acquireBuffer()
    MPM-->>WS: buffer
    WS->>SM: writeChunk(streamId, data)
    SM->>SC: get context
    SC->>MMC: write(offset, data)
    MMC->>OS: memcpy to mmap
    OS-->>MMC: success
    MMC-->>SC: bytes written
    SC->>SC: update offset
    SC-->>SM: success
    SM-->>WS: success
    WS->>MPM: releaseBuffer(buffer)
    WS-->>Client: ack
    
    Note over Client,OS: 读取数据
    Client->>WS: download request
    WS->>SM: readChunk(streamId, offset, length)
    SM->>SC: get context
    SC->>MMC: read(offset, length)
    MMC->>OS: read from mmap
    OS-->>MMC: data
    MMC-->>SC: bytes
    SC-->>SM: bytes
    SM-->>WS: bytes
    WS-->>Client: send chunk
    
    Note over Client,OS: 完成流
    Client->>WS: finalize request
    WS->>SM: finalizeStream(streamId)
    SM->>SC: get context
    SC->>MMC: finalize(finalSize)
    MMC->>OS: truncate + flush
    OS-->>MMC: success
    MMC-->>SC: success
    SC->>SC: status = READY
    SC-->>SM: success
    SM-->>WS: success
    WS-->>Client: complete
    
    Note over Client,OS: 删除流
    WS->>SM: deleteStream(streamId)
    SM->>SC: get context
    SC->>MMC: close()
    MMC->>OS: unmap + delete file
    OS-->>MMC: success
    MMC-->>SC: closed
    SM->>SM: remove from map
    SM-->>WS: success
```

### 线程安全机制图

```mermaid
graph TB
    subgraph "MemoryMappedCache 线程安全"
        RWL[ReadWriteLock<br/>shared_mutex/ReadWriteLock]
        READ[读操作<br/>read/readBatch]
        WRITE[写操作<br/>write/writeBatch/resize]
        SEG[分段映射<br/>ConcurrentHashMap]
        
        READ --> |获取共享锁| RWL
        WRITE --> |获取独占锁| RWL
        READ --> |并发访问| SEG
        WRITE --> |并发访问| SEG
    end
    
    subgraph "StreamManager 线程安全"
        MTX1[Mutex<br/>mutex/ReentrantLock]
        MAP1[streams Map]
        OPS1[createStream<br/>getStream<br/>deleteStream]
        
        OPS1 --> |保护访问| MTX1
        MTX1 --> |锁定| MAP1
    end
    
    subgraph "MemoryPoolManager 线程安全"
        MTX2[Mutex<br/>mutex/ReentrantLock]
        QUEUE[availableBuffers Queue]
        OPS2[acquireBuffer<br/>releaseBuffer]
        
        OPS2 --> |保护访问| MTX2
        MTX2 --> |锁定| QUEUE
    end
    
    style RWL fill:#ffeb3b
    style MTX1 fill:#ffeb3b
    style MTX2 fill:#ffeb3b
    style READ fill:#4caf50
    style WRITE fill:#f44336
    style SEG fill:#2196f3
```

### 内存分段映射图

```mermaid
graph LR
    subgraph "大文件 > 2GB"
        FILE[Physical File<br/>3.5 GB]
    end
    
    subgraph "分段映射"
        SEG0[Segment 0<br/>0-1GB<br/>Mapped]
        SEG1[Segment 1<br/>1-2GB<br/>Mapped]
        SEG2[Segment 2<br/>2-3GB<br/>Mapped]
        SEG3[Segment 3<br/>3-3.5GB<br/>Not Mapped]
    end
    
    subgraph "内存映射表"
        MAP["Map&lt;segmentIndex, address&gt;<br/>0 → 0x7f8a00000000<br/>1 → 0x7f8a40000000<br/>2 → 0x7f8a80000000"]
    end
    
    FILE --> SEG0
    FILE --> SEG1
    FILE --> SEG2
    FILE --> SEG3
    
    SEG0 --> |按需加载| MAP
    SEG1 --> |按需加载| MAP
    SEG2 --> |按需加载| MAP
    SEG3 --> |延迟加载| MAP
    
    style FILE fill:#e3f2fd
    style SEG0 fill:#4caf50
    style SEG1 fill:#4caf50
    style SEG2 fill:#4caf50
    style SEG3 fill:#9e9e9e
    style MAP fill:#ffeb3b
```

### 生命周期状态图

```mermaid
stateDiagram-v2
    [*] --> Created: createStream()
    Created --> Uploading: first write
    Uploading --> Uploading: writeChunk()
    Uploading --> Ready: finalizeStream()
    Uploading --> Error: write error
    Ready --> Ready: readChunk()
    Ready --> Deleted: deleteStream()
    Error --> Deleted: deleteStream()
    Deleted --> [*]
    
    note right of Created
        StreamContext created
        MemoryMappedCache initialized
        File created on disk
    end note
    
    note right of Uploading
        Accepting write operations
        Offset incrementing
        Data being written
    end note
    
    note right of Ready
        File finalized
        Read-only access
        Available for download
    end note
    
    note right of Error
        Operation failed
        Needs cleanup
    end note
```

### 性能优化策略图

```mermaid
mindmap
    root((性能优化))
        分段映射
            1GB段大小
            延迟加载
            最大8GB缓存
            按需映射
        批量操作
            writeBatch
            readBatch
            最多1000操作/批
            减少系统调用
        内存管理
            prefetch预取
            evict驱逐
            flush同步
            顺序访问优化
        缓冲区复用
            预分配池
            64KB默认大小
            100个默认数量
            减少分配开销
        线程安全
            读写锁
            并发读
            互斥写
            细粒度锁
```

### 错误处理流程图

```mermaid
flowchart TD
    START([操作开始]) --> CHECK{检查参数}
    CHECK -->|无效| ERR1[InvalidOperation/InvalidOffset/InvalidSize]
    CHECK -->|有效| LOCK[获取锁]
    LOCK --> EXEC{执行操作}
    EXEC -->|文件不存在| ERR2[FileNotFound]
    EXEC -->|权限不足| ERR3[PermissionError]
    EXEC -->|内存不足| ERR4[MemoryError]
    EXEC -->|成功| LOG1[记录成功日志]
    ERR1 --> LOG2[记录错误日志]
    ERR2 --> LOG2
    ERR3 --> LOG2
    ERR4 --> LOG2
    LOG2 --> RETURN1[返回false/抛出异常]
    LOG1 --> UNLOCK[释放锁]
    UNLOCK --> RETURN2[返回结果]
    RETURN1 --> END([操作结束])
    RETURN2 --> END
    
    style ERR1 fill:#f44336
    style ERR2 fill:#f44336
    style ERR3 fill:#f44336
    style ERR4 fill:#f44336
    style LOG1 fill:#4caf50
    style LOG2 fill:#ff9800
```

### 平台适配层图

```mermaid
graph TB
    subgraph "统一接口层"
        API[MemoryMappedCache API<br/>create/open/close/read/write]
    end
    
    subgraph "平台抽象层"
        WIN[Windows Implementation]
        POSIX[POSIX Implementation]
    end
    
    subgraph "Windows API"
        CF[CreateFileMapping]
        MV[MapViewOfFile]
        UV[UnmapViewOfFile]
        CH[CloseHandle]
    end
    
    subgraph "POSIX API"
        OPEN[open]
        MMAP[mmap]
        MUNMAP[munmap]
        MSYNC[msync]
        CLOSE[close]
    end
    
    API --> WIN
    API --> POSIX
    WIN --> CF
    WIN --> MV
    WIN --> UV
    WIN --> CH
    POSIX --> OPEN
    POSIX --> MMAP
    POSIX --> MUNMAP
    POSIX --> MSYNC
    POSIX --> CLOSE
    
    style API fill:#2196f3
    style WIN fill:#00bcd4
    style POSIX fill:#00bcd4
    style CF fill:#4caf50
    style MV fill:#4caf50
    style UV fill:#4caf50
    style CH fill:#4caf50
    style OPEN fill:#8bc34a
    style MMAP fill:#8bc34a
    style MUNMAP fill:#8bc34a
    style MSYNC fill:#8bc34a
    style CLOSE fill:#8bc34a
```

---

## 配置参数

### MemoryMappedCache

```
SEGMENT_SIZE = 1GB              // 分段大小
MAX_CACHE_SIZE = 8GB            // 最大缓存大小
BATCH_OPERATION_LIMIT = 1000    // 批量操作限制
```

### StreamManager

```
CLEANUP_AGE = 24 hours          // 清理时间（超过此时间的流将被删除）
```

### MemoryPoolManager

```
DEFAULT_BUFFER_SIZE = 64KB      // 默认缓冲区大小
DEFAULT_POOL_SIZE = 100         // 默认池大小
```


---

## 统一端到端验证方式 (Unified End-to-End Verification)

### 概述 (Overview)

端到端验证是确保客户端实现正确性的关键步骤。本节定义了一个标准化的验证流程，适用于所有编程语言的客户端实现（C++、Java 及未来的其他语言）。

验证流程包括：
1. **上传阶段**：将测试文件上传到服务器
2. **下载阶段**：从服务器下载相同的文件
3. **完整性验证**：使用 SHA-256 校验和验证文件一致性
4. **性能测量**：测量上传和下载吞吐量
5. **结果报告**：生成标准化的验证报告

End-to-end verification is a critical step to ensure client implementation correctness. This section defines a standardized verification workflow applicable to all programming language client implementations (C++, Java, and future languages).

The verification workflow includes:
1. **Upload Phase**: Upload test file to server
2. **Download Phase**: Download the same file from server
3. **Integrity Verification**: Verify file consistency using SHA-256 checksum
4. **Performance Measurement**: Measure upload and download throughput
5. **Result Reporting**: Generate standardized verification report

### 验证工作流程 (Verification Workflow)

```mermaid
stateDiagram-v2
    [*] --> ParseArguments: 启动客户端<br/>Start Client
    ParseArguments --> ValidateInputs: 解析命令行参数<br/>Parse CLI Args
    ValidateInputs --> ConnectServer: 验证输入<br/>Validate Inputs
    ConnectServer --> StartUpload: 连接服务器<br/>Connect to Server
    StartUpload --> UploadChunks: 开始上传<br/>Start Upload
    UploadChunks --> UploadChunks: 发送数据块<br/>Send Chunks
    UploadChunks --> EndUpload: 完成上传<br/>Complete Upload
    EndUpload --> StartDownload: 记录性能<br/>Record Performance
    StartDownload --> ReceiveChunks: 开始下载<br/>Start Download
    ReceiveChunks --> ReceiveChunks: 接收数据块<br/>Receive Chunks
    ReceiveChunks --> EndDownload: 完成下载<br/>Complete Download
    EndDownload --> VerifyIntegrity: 记录性能<br/>Record Performance
    VerifyIntegrity --> CheckPerformance: 计算校验和<br/>Compute Checksum
    CheckPerformance --> GenerateReport: 检查性能目标<br/>Check Targets
    GenerateReport --> Disconnect: 生成报告<br/>Generate Report
    Disconnect --> Success: 断开连接<br/>Disconnect
    Success --> [*]: 退出(0)<br/>Exit(0)
    
    ParseArguments --> Error: 参数错误<br/>Invalid Args
    ValidateInputs --> Error: 验证失败<br/>Validation Failed
    ConnectServer --> Error: 连接失败<br/>Connection Failed
    UploadChunks --> Error: 上传错误<br/>Upload Error
    ReceiveChunks --> Error: 下载错误<br/>Download Error
    VerifyIntegrity --> Error: 校验失败<br/>Checksum Mismatch
    Error --> [*]: 退出(1)<br/>Exit(1)
    
    note right of ParseArguments
        --server <uri>
        --input <file>
        --output <file>
        --verbose
    end note
    
    note right of VerifyIntegrity
        SHA-256 checksum
        File size comparison
        Byte-by-byte verification
    end note
    
    note right of CheckPerformance
        Upload: >100 Mbps
        Download: >200 Mbps
    end note
```

### 完整生命周期流程 (Complete Lifecycle Flow)

```mermaid
sequenceDiagram
    participant User
    participant Client
    participant WS as WebSocket Server
    participant SM as StreamManager
    participant MMC as MemoryMappedCache
    
    Note over User,MMC: 1. 初始化阶段 (Initialization Phase)
    User->>Client: 启动客户端<br/>./client --input test.mp3
    Client->>Client: 解析参数<br/>Parse arguments
    Client->>Client: 验证输入文件<br/>Validate input file
    Client->>WS: 连接 WebSocket<br/>Connect WebSocket
    WS-->>Client: 连接成功<br/>Connected
    
    Note over User,MMC: 2. 上传阶段 (Upload Phase)
    Client->>Client: 开始性能监控<br/>Start performance monitor
    Client->>Client: 生成 streamId<br/>Generate streamId
    Client->>WS: START message (streamId)
    WS->>SM: createStream(streamId)
    SM->>MMC: create cache file
    MMC-->>SM: cache created
    SM-->>WS: stream ready
    WS-->>Client: START ACK
    
    loop 每个数据块 (For each chunk)
        Client->>Client: 读取 64KB 块<br/>Read 64KB chunk
        Client->>WS: 发送二进制数据<br/>Send binary data
        WS->>SM: writeChunk(streamId, data)
        SM->>MMC: write(offset, data)
        MMC-->>SM: bytes written
        SM-->>WS: success
        WS-->>Client: 进度更新<br/>Progress update
    end
    
    Client->>WS: STOP message (streamId)
    WS->>SM: finalizeStream(streamId)
    SM->>MMC: finalize(finalSize)
    MMC-->>SM: finalized
    SM-->>WS: stream ready
    WS-->>Client: STOP ACK
    Client->>Client: 结束性能监控<br/>End performance monitor
    
    Note over User,MMC: 3. 下载阶段 (Download Phase)
    Client->>Client: 开始性能监控<br/>Start performance monitor
    Client->>WS: GET message (streamId)
    WS->>SM: getStream(streamId)
    SM-->>WS: stream context
    
    loop 每个数据块 (For each chunk)
        WS->>SM: readChunk(streamId, offset, 64KB)
        SM->>MMC: read(offset, 64KB)
        MMC-->>SM: data
        SM-->>WS: data
        WS-->>Client: 发送二进制数据<br/>Send binary data
        Client->>Client: 写入文件<br/>Write to file
    end
    
    WS-->>Client: 传输完成<br/>Transfer complete
    Client->>Client: 结束性能监控<br/>End performance monitor
    
    Note over User,MMC: 4. 验证阶段 (Verification Phase)
    Client->>Client: 计算原始文件 SHA-256<br/>Compute original SHA-256
    Client->>Client: 计算下载文件 SHA-256<br/>Compute downloaded SHA-256
    Client->>Client: 比较校验和<br/>Compare checksums
    Client->>Client: 比较文件大小<br/>Compare file sizes
    
    alt 验证通过 (Verification Passed)
        Client->>Client: ✓ 文件一致<br/>✓ Files identical
        Client->>Client: 生成性能报告<br/>Generate performance report
        Client->>User: 显示成功报告<br/>Display success report
        Client->>WS: 断开连接<br/>Disconnect
        Client->>User: 退出(0)<br/>Exit(0)
    else 验证失败 (Verification Failed)
        Client->>Client: ✗ 文件不一致<br/>✗ Files differ
        Client->>User: 显示错误详情<br/>Display error details
        Client->>WS: 断开连接<br/>Disconnect
        Client->>User: 退出(1)<br/>Exit(1)
    end
```


### 命令行接口标准 (Command-Line Interface Standards)

所有客户端实现必须支持以下标准命令行选项：

All client implementations MUST support the following standard command-line options:

#### 必需选项 (Required Options)

| 选项 (Option) | 参数 (Argument) | 说明 (Description) | 默认值 (Default) |
|--------------|----------------|-------------------|-----------------|
| `--input` | `<file_path>` | 输入文件路径（上传的文件）<br/>Input file path (file to upload) | 无 (None) - 必需 (Required) |

#### 可选选项 (Optional Options)

| 选项 (Option) | 参数 (Argument) | 说明 (Description) | 默认值 (Default) |
|--------------|----------------|-------------------|-----------------|
| `--server` | `<uri>` | WebSocket 服务器 URI<br/>WebSocket server URI | `ws://localhost:8080/audio` |
| `--output` | `<file_path>` | 输出文件路径（下载的文件）<br/>Output file path (downloaded file) | `audio/output/output-{timestamp}-test.mp3` |
| `--verbose` 或 `-v` | 无 (None) | 启用详细日志输出<br/>Enable verbose logging | 禁用 (Disabled) |
| `--help` 或 `-h` | 无 (None) | 显示帮助信息<br/>Display help message | N/A | 

### 验证标准 (Verification Criteria)

#### 文件完整性验证 (File Integrity Verification)

文件完整性验证是端到端测试的核心，确保上传和下载的文件完全一致。

File integrity verification is the core of end-to-end testing, ensuring uploaded and downloaded files are identical.

**验证步骤 (Verification Steps):**

1. **计算原始文件校验和 (Compute Original File Checksum)**
   - 算法：SHA-256
   - 输入：原始输入文件的全部字节
   - 输出：64 字符的十六进制字符串

2. **计算下载文件校验和 (Compute Downloaded File Checksum)**
   - 算法：SHA-256
   - 输入：下载输出文件的全部字节
   - 输出：64 字符的十六进制字符串

3. **比较文件大小 (Compare File Sizes)**
   - 原始文件大小（字节）
   - 下载文件大小（字节）
   - 必须完全相等

4. **比较校验和 (Compare Checksums)**
   - 原始文件 SHA-256
   - 下载文件 SHA-256
   - 必须完全匹配（大小写不敏感）

**验证报告格式 (Verification Report Format):**

```
=== Verifying File Integrity ===
Original file: audio/input/test.mp3
Downloaded file: audio/output/output-20260124-103015-test.mp3
Original size: 5242880 bytes
Downloaded size: 5242880 bytes
Original checksum (SHA-256): a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
Downloaded checksum (SHA-256): a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
✓ File verification PASSED - Files are identical
```

**成功标准 (Success Criteria):**

- ✅ 文件大小相等 (File sizes are equal)
- ✅ SHA-256 校验和匹配 (SHA-256 checksums match)
- ✅ 无数据损坏 (No data corruption)
- ✅ 无字节丢失或添加 (No bytes lost or added)

**失败场景 (Failure Scenarios):**

```
=== Verifying File Integrity ===
Original file: audio/input/test.mp3
Downloaded file: audio/output/output-20260124-103520-test.mp3
Original size: 5242880 bytes
Downloaded size: 5242816 bytes
Original checksum (SHA-256): a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
Downloaded checksum (SHA-256): f2e1d0c9b8a7z6y5x4w3v2u1t0s9r8q7p6o5n4m3l2k1j0i9h8g7f6e5d4c3b2a1
✗ File verification FAILED
  Reason: File size mismatch (expected 5242880, got 5242816)
  Reason: Checksum mismatch
```

#### 校验和算法规范 (Checksum Algorithm Specification)

**SHA-256 实现要求 (SHA-256 Implementation Requirements):**

1. **算法标准 (Algorithm Standard)**
   - 遵循 FIPS 180-4 标准
   - 256 位（32 字节）输出
   - 64 字符十六进制表示

2. **实现库 (Implementation Libraries)**
   - **C++**: OpenSSL (`SHA256()` 函数)
   - **Java**: `java.security.MessageDigest` ("SHA-256")
   - **Python**: `hashlib.sha256()`
   - **Node.js**: `crypto.createHash('sha256')`
   - **Go**: `crypto/sha256`
   - **Rust**: `sha2` crate

3. **计算方式 (Computation Method)**
   ```
   1. 打开文件以二进制模式读取
   2. 初始化 SHA-256 上下文
   3. 分块读取文件（推荐 64KB 块）
   4. 对每个块更新 SHA-256 上下文
   5. 完成计算并获取最终哈希值
   6. 转换为十六进制字符串（小写）
   ```
 

#### 验证决策逻辑 (Verification Decision Logic)

```mermaid
flowchart TD
    START([开始验证<br/>Start Verification]) --> COMPUTE_ORIG[计算原始文件 SHA-256<br/>Compute Original SHA-256]
    COMPUTE_ORIG --> COMPUTE_DOWN[计算下载文件 SHA-256<br/>Compute Downloaded SHA-256]
    COMPUTE_DOWN --> GET_SIZE_ORIG[获取原始文件大小<br/>Get Original File Size]
    GET_SIZE_ORIG --> GET_SIZE_DOWN[获取下载文件大小<br/>Get Downloaded File Size]
    GET_SIZE_DOWN --> COMPARE_SIZE{文件大小相等?<br/>Sizes Equal?}
    
    COMPARE_SIZE -->|否 No| FAIL_SIZE[验证失败: 大小不匹配<br/>FAILED: Size Mismatch]
    COMPARE_SIZE -->|是 Yes| COMPARE_HASH{校验和匹配?<br/>Checksums Match?}
    
    COMPARE_HASH -->|否 No| FAIL_HASH[验证失败: 校验和不匹配<br/>FAILED: Checksum Mismatch]
    COMPARE_HASH -->|是 Yes| SUCCESS[验证通过<br/>PASSED]
    
    FAIL_SIZE --> LOG_ERROR[记录错误详情<br/>Log Error Details]
    FAIL_HASH --> LOG_ERROR
    LOG_ERROR --> EXIT_FAIL[退出代码 1<br/>Exit Code 1]
    
    SUCCESS --> LOG_SUCCESS[记录成功信息<br/>Log Success Info]
    LOG_SUCCESS --> EXIT_SUCCESS[退出代码 0<br/>Exit Code 0]
    
    EXIT_FAIL --> END([结束<br/>End])
    EXIT_SUCCESS --> END
    
    style START fill:#e3f2fd
    style SUCCESS fill:#4caf50
    style FAIL_SIZE fill:#f44336
    style FAIL_HASH fill:#f44336
    style EXIT_SUCCESS fill:#4caf50
    style EXIT_FAIL fill:#f44336
    style END fill:#e3f2fd
```


### 性能目标和测量 (Performance Targets and Measurement)

#### 性能目标 (Performance Targets)

所有客户端实现应该努力达到以下性能目标：

All client implementations should strive to meet the following performance targets:

| 指标 (Metric) | 目标值 (Target) | 说明 (Description) |
|--------------|----------------|-------------------|
| **上传吞吐量 (Upload Throughput)** | > 100 Mbps | 从客户端到服务器的数据传输速率<br/>Data transfer rate from client to server |
| **下载吞吐量 (Download Throughput)** | > 200 Mbps | 从服务器到客户端的数据传输速率<br/>Data transfer rate from server to client |
| **连接建立时间 (Connection Time)** | < 1 秒 (second) | WebSocket 连接建立的时间<br/>Time to establish WebSocket connection |
| **端到端延迟 (End-to-End Latency)** | < 5 秒 (seconds) | 完整上传-下载-验证周期的总时间（5MB 文件）<br/>Total time for complete upload-download-verify cycle (5MB file) |

**注意 (Note):** 性能目标是指导性的，实际性能取决于网络条件、硬件性能和文件大小。未达到目标不会导致验证失败，但会记录警告。

Performance targets are guidelines; actual performance depends on network conditions, hardware performance, and file size. Not meeting targets does not cause verification failure but will log a warning.

#### 吞吐量计算公式 (Throughput Calculation Formula)

**吞吐量 (Throughput) = (文件大小 × 8) / (传输时间 × 1,000,000)**

其中 (Where):
- 文件大小 (File Size): 字节 (bytes)
- 传输时间 (Transfer Time): 毫秒 (milliseconds)
- 结果单位 (Result Unit): Mbps (兆比特每秒 / Megabits per second)

**示例计算 (Example Calculation):**

```
文件大小 (File Size) = 5,242,880 bytes (5 MB)
上传时间 (Upload Time) = 554 ms
下载时间 (Download Time) = 505 ms

上传吞吐量 (Upload Throughput) = (5,242,880 × 8) / (554 × 1,000,000)
                                = 41,943,040 / 554,000,000
                                = 75.68 Mbps

下载吞吐量 (Download Throughput) = (5,242,880 × 8) / (505 × 1,000,000)
                                  = 41,943,040 / 505,000,000
                                  = 83.01 Mbps
```

#### 性能测量实现 (Performance Measurement Implementation)

**测量点 (Measurement Points):**

1. **上传阶段 (Upload Phase)**
   ```
   开始时间 (Start Time): 发送 START 消息之前
   结束时间 (End Time): 收到 STOP ACK 之后
   测量数据 (Measured Data): 文件总大小（字节）
   ```

2. **下载阶段 (Download Phase)**
   ```
   开始时间 (Start Time): 发送 GET 消息之前
   结束时间 (End Time): 接收最后一个数据块之后
   测量数据 (Measured Data): 文件总大小（字节）
   ```

**时间戳精度要求 (Timestamp Precision Requirements):**

- 最小精度：毫秒 (Minimum precision: milliseconds)
- 推荐精度：微秒 (Recommended precision: microseconds)
- 使用系统高精度时钟 (Use system high-resolution clock)
 

#### 性能报告格式 (Performance Report Format)

**标准输出格式 (Standard Output Format):**

```
=== Performance Report ===
Upload Duration: 554 ms
Upload Throughput: 75.68 Mbps
Download Duration: 505 ms
Download Throughput: 83.01 Mbps
Total Duration: 1059 ms
Average Throughput: 79.35 Mbps

Performance Target Status:
  Upload Throughput: ⚠ Below target (75.68 Mbps < 100 Mbps)
  Download Throughput: ⚠ Below target (83.01 Mbps < 200 Mbps)
```

**达到目标时的输出 (Output When Targets Met):**

```
=== Performance Report ===
Upload Duration: 350 ms
Upload Throughput: 119.81 Mbps
Download Duration: 180 ms
Download Throughput: 232.91 Mbps
Total Duration: 530 ms
Average Throughput: 176.36 Mbps

Performance Target Status:
  ✓ Upload Throughput: Target met (119.81 Mbps > 100 Mbps)
  ✓ Download Throughput: Target met (232.91 Mbps > 200 Mbps)
  ✓ Performance targets achieved
```

#### 性能优化建议 (Performance Optimization Recommendations)

1. **网络优化 (Network Optimization)**
   - 使用本地网络进行测试以减少延迟
   - 确保服务器和客户端在同一网段
   - 避免 VPN 或代理连接

2. **系统优化 (System Optimization)**
   - 关闭不必要的后台应用程序
   - 使用 SSD 而非 HDD 存储测试文件
   - 确保有足够的可用内存

3. **实现优化 (Implementation Optimization)**
   - 使用适当的缓冲区大小（推荐 64KB）
   - 实现批量操作以减少系统调用
   - 使用异步 I/O 操作
   - 启用 WebSocket 压缩（如果支持）

4. **测试文件选择 (Test File Selection)**
   - 使用至少 5MB 的文件以获得准确的吞吐量测量
   - 避免使用过小的文件（< 1MB），因为连接开销会影响结果
   - 使用真实的音频/视频文件而非随机数据



### 输出格式规范 (Output Format Specification)

#### 日志格式标准 (Log Format Standards)

所有客户端实现必须遵循统一的日志格式，以便于调试和监控。

All client implementations MUST follow a unified log format for ease of debugging and monitoring.

**标准日志格式 (Standard Log Format):**

```
[YYYY-MM-DD HH:MM:SS.mmm] [level] message
```

**字段说明 (Field Descriptions):**

| 字段 (Field) | 格式 (Format) | 说明 (Description) | 示例 (Example) |
|-------------|--------------|-------------------|---------------|
| 日期 (Date) | YYYY-MM-DD | ISO 8601 日期格式 | 2026-01-24 |
| 时间 (Time) | HH:MM:SS.mmm | 24 小时制，毫秒精度 | 10:30:15.123 |
| 级别 (Level) | info/warn/error/debug | 日志级别（小写）| info |
| 消息 (Message) | 自由文本 (Free text) | 日志消息内容 | Successfully connected to server |

**日志级别定义 (Log Level Definitions):**

| 级别 (Level) | 用途 (Purpose) | 示例 (Example) |
|-------------|---------------|---------------|
| **debug** | 详细调试信息（仅在 --verbose 模式）<br/>Detailed debug info (only in --verbose mode) | Received server response: {"type":"START_ACK"} |
| **info** | 一般信息性消息<br/>General informational messages | Upload completed successfully |
| **warn** | 警告消息（不影响功能）<br/>Warning messages (does not affect functionality) | Performance targets not met |
| **error** | 错误消息（影响功能）<br/>Error messages (affects functionality) | Failed to connect to server |

#### 阶段性输出标准 (Phase Output Standards)

客户端应该在每个主要阶段输出清晰的分隔标记：

Clients should output clear phase separators for each major stage:

```
=== Phase Name ===
```

**标准阶段标记 (Standard Phase Markers):**

1. `=== Connecting to Server ===`
2. `=== Starting Upload ===`
3. `=== Starting Download ===`
4. `=== Verifying File Integrity ===`
5. `=== Performance Report ===`
6. `=== Error Statistics ===`
7. `=== Workflow Complete ===`

#### 进度报告格式 (Progress Report Format)

**上传/下载进度 (Upload/Download Progress):**

```
[timestamp] [info] Upload progress: {current}/{total} bytes ({percentage}%)
[timestamp] [info] Download progress: {current}/{total} bytes ({percentage}%)
```

**示例 (Example):**

```
[2026-01-24 10:30:15.345] [info] Upload progress: 1310720/5242880 bytes (25%)
[2026-01-24 10:30:15.456] [info] Upload progress: 2621440/5242880 bytes (50%)
[2026-01-24 10:30:15.567] [info] Upload progress: 3932160/5242880 bytes (75%)
[2026-01-24 10:30:15.678] [info] Upload progress: 5242880/5242880 bytes (100%)
```

**进度报告规则 (Progress Reporting Rules):**

- 至少在 25%, 50%, 75%, 100% 时报告进度
- 对于大文件（> 100MB），可以更频繁地报告（每 10%）
- 进度百分比应该四舍五入到整数
- 字节数应该使用逗号分隔（可选，取决于语言/地区）

#### 错误报告格式 (Error Report Format)

**错误消息格式 (Error Message Format):**

```
[timestamp] [error] Error description
[timestamp] [error] Context: additional context information
[timestamp] [error] Suggested action: what user should do
```

**示例 (Example):**

```
[2026-01-24 10:35:20.234] [error] Failed to connect to server: Connection refused
[2026-01-24 10:35:20.235] [error] Context: Server URI: ws://localhost:8080/audio
[2026-01-24 10:35:20.236] [error] Suggested action: Ensure server is running and accessible
```

**错误统计报告 (Error Statistics Report):**

```
=== Error Statistics ===
Connection errors: {count}
File I/O errors: {count}
Protocol errors: {count}
Timeout errors: {count}
Validation errors: {count}
```

#### 指标报告格式 (Metrics Report Format)

**性能指标 (Performance Metrics):**

```
=== Performance Report ===
Upload Duration: {duration} ms
Upload Throughput: {throughput} Mbps
Download Duration: {duration} ms
Download Throughput: {throughput} Mbps
Total Duration: {duration} ms
Average Throughput: {throughput} Mbps
```

**数值格式规则 (Numeric Format Rules):**

- 持续时间 (Duration): 整数毫秒 (Integer milliseconds)
- 吞吐量 (Throughput): 保留 2 位小数 (2 decimal places)
- 文件大小 (File Size): 整数字节 (Integer bytes)
- 百分比 (Percentage): 整数 (Integer)

#### 验证报告格式 (Verification Report Format)

**完整验证报告 (Complete Verification Report):**

```
=== Verifying File Integrity ===
Original file: {original_path}
Downloaded file: {downloaded_path}
Original size: {size} bytes
Downloaded size: {size} bytes
Original checksum (SHA-256): {checksum}
Downloaded checksum (SHA-256): {checksum}
{result_symbol} File verification {PASSED|FAILED} - {description}
```

**结果符号 (Result Symbols):**

- 成功 (Success): `✓` (U+2713)
- 失败 (Failure): `✗` (U+2717)
- 警告 (Warning): `⚠` (U+26A0)

#### 完整输出示例 (Complete Output Example)

**成功场景完整输出 (Complete Successful Scenario Output):**

```
[2026-01-24 10:30:15.123] [info] Audio Stream Cache Client - C++ Implementation
[2026-01-24 10:30:15.124] [info] Server URI: ws://localhost:8080/audio
[2026-01-24 10:30:15.124] [info] Input file: audio/input/test.mp3
[2026-01-24 10:30:15.124] [info] Output file: audio/output/output-20260124-103015-test.mp3
[2026-01-24 10:30:15.125] [info] Input file size: 5242880 bytes

[2026-01-24 10:30:15.126] [info] === Connecting to Server ===
[2026-01-24 10:30:15.234] [info] Successfully connected to server

[2026-01-24 10:30:15.235] [info] === Starting Upload ===
[2026-01-24 10:30:15.236] [info] Generated stream ID: stream-20260124-103015-a1b2c3d4
[2026-01-24 10:30:15.345] [info] Upload progress: 1310720/5242880 bytes (25%)
[2026-01-24 10:30:15.456] [info] Upload progress: 2621440/5242880 bytes (50%)
[2026-01-24 10:30:15.567] [info] Upload progress: 3932160/5242880 bytes (75%)
[2026-01-24 10:30:15.678] [info] Upload progress: 5242880/5242880 bytes (100%)
[2026-01-24 10:30:15.789] [info] Upload completed successfully with stream ID: stream-20260124-103015-a1b2c3d4

[2026-01-24 10:30:15.790] [info] === Starting Download ===
[2026-01-24 10:30:15.891] [info] Download progress: 1310720/5242880 bytes (25%)
[2026-01-24 10:30:15.992] [info] Download progress: 2621440/5242880 bytes (50%)
[2026-01-24 10:30:16.093] [info] Download progress: 3932160/5242880 bytes (75%)
[2026-01-24 10:30:16.194] [info] Download progress: 5242880/5242880 bytes (100%)
[2026-01-24 10:30:16.295] [info] Download completed successfully

[2026-01-24 10:30:16.296] [info] === Verifying File Integrity ===
[2026-01-24 10:30:16.296] [info] Original file: audio/input/test.mp3
[2026-01-24 10:30:16.296] [info] Downloaded file: audio/output/output-20260124-103015-test.mp3
[2026-01-24 10:30:16.296] [info] Original size: 5242880 bytes
[2026-01-24 10:30:16.296] [info] Downloaded size: 5242880 bytes
[2026-01-24 10:30:16.397] [info] Original checksum (SHA-256): a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
[2026-01-24 10:30:16.397] [info] Downloaded checksum (SHA-256): a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
[2026-01-24 10:30:16.397] [info] ✓ File verification PASSED - Files are identical

[2026-01-24 10:30:16.398] [info] === Performance Report ===
[2026-01-24 10:30:16.398] [info] Upload Duration: 554 ms
[2026-01-24 10:30:16.398] [info] Upload Throughput: 75.68 Mbps
[2026-01-24 10:30:16.398] [info] Download Duration: 505 ms
[2026-01-24 10:30:16.398] [info] Download Throughput: 83.01 Mbps
[2026-01-24 10:30:16.398] [info] Total Duration: 1059 ms
[2026-01-24 10:30:16.398] [info] Average Throughput: 79.35 Mbps
[2026-01-24 10:30:16.398] [warn] ⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)

[2026-01-24 10:30:16.399] [info] Disconnected from server

[2026-01-24 10:30:16.399] [info] === Error Statistics ===
[2026-01-24 10:30:16.399] [info] Connection errors: 0
[2026-01-24 10:30:16.399] [info] File I/O errors: 0
[2026-01-24 10:30:16.399] [info] Protocol errors: 0
[2026-01-24 10:30:16.399] [info] Timeout errors: 0
[2026-01-24 10:30:16.399] [info] Validation errors: 0

[2026-01-24 10:30:16.400] [info] === Workflow Complete ===
[2026-01-24 10:30:16.400] [info] Successfully uploaded, downloaded, and verified file: audio/input/test.mp3

Exit code: 0
```



### 故障排除指南 (Troubleshooting Guide)

#### 常见问题和解决方案 (Common Issues and Solutions)

##### 1. 连接失败 (Connection Failures)

**问题症状 (Symptoms):**
```
[error] Failed to connect to server: Connection refused
[error] Retry attempt 1/3 failed
```

**可能原因 (Possible Causes):**
- 服务器未启动
- 服务器地址或端口错误
- 防火墙阻止连接
- 网络连接问题

**解决方案 (Solutions):**

1. **验证服务器正在运行 (Verify Server is Running)**
   ```bash
   # 检查服务器进程 (Check server process)
   ps aux | grep audio_stream_server  # Linux/macOS
   tasklist | findstr audio_stream_server  # Windows
   
   # 检查端口是否监听 (Check if port is listening)
   netstat -an | grep 8080  # Linux/macOS
   netstat -an | findstr 8080  # Windows
   ```

2. **验证服务器地址 (Verify Server Address)**
   ```bash
   # 测试连接 (Test connection)
   telnet localhost 8080
   # 或 (or)
   nc -zv localhost 8080
   ```

3. **检查防火墙设置 (Check Firewall Settings)**
   ```bash
   # Linux (iptables)
   sudo iptables -L -n | grep 8080
   
   # macOS
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
   
   # Windows
   netsh advfirewall firewall show rule name=all | findstr 8080
   ```

4. **使用正确的 URI 格式 (Use Correct URI Format)**
   ```
   正确 (Correct): ws://localhost:8080/audio
   错误 (Wrong): http://localhost:8080/audio
   错误 (Wrong): localhost:8080/audio
   ```

##### 2. 文件验证失败 (File Verification Failures)

**问题症状 (Symptoms):**
```
[error] ✗ File verification FAILED
[error]   Reason: Checksum mismatch
```

**可能原因 (Possible Causes):**
- 数据传输过程中损坏
- 服务器端缓存问题
- 网络不稳定
- 内存映射文件未正确刷新

**解决方案 (Solutions):**

1. **重新运行测试 (Re-run Test)**
   ```bash
   # 清理输出目录 (Clean output directory)
   rm -rf audio/output/*
   
   # 重新运行客户端 (Re-run client)
   ./audio_stream_client --input audio/input/test.mp3
   ```

2. **检查服务器日志 (Check Server Logs)**
   ```bash
   # 查看服务器日志 (View server logs)
   tail -f logs/server.log
   ```

3. **验证输入文件完整性 (Verify Input File Integrity)**
   ```bash
   # 计算输入文件校验和 (Compute input file checksum)
   sha256sum audio/input/test.mp3  # Linux/macOS
   certutil -hashfile audio\input\test.mp3 SHA256  # Windows
   ```

4. **使用详细模式调试 (Debug with Verbose Mode)**
   ```bash
   ./audio_stream_client --input audio/input/test.mp3 --verbose
   ```

##### 3. 性能问题 (Performance Issues)

**问题症状 (Symptoms):**
```
[warn] ⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)
Upload Throughput: 15.23 Mbps
Download Throughput: 18.45 Mbps
```

**可能原因 (Possible Causes):**
- 网络延迟高
- 磁盘 I/O 慢
- CPU 负载高
- 内存不足

**解决方案 (Solutions):**

1. **检查网络延迟 (Check Network Latency)**
   ```bash
   # 测试延迟 (Test latency)
   ping localhost
   
   # 测试带宽 (Test bandwidth)
   iperf3 -c localhost -p 5201
   ```

2. **检查磁盘性能 (Check Disk Performance)**
   ```bash
   # Linux
   iostat -x 1
   
   # macOS
   sudo fs_usage -w | grep audio
   
   # Windows
   perfmon /res
   ```

3. **检查系统资源 (Check System Resources)**
   ```bash
   # CPU 和内存使用 (CPU and memory usage)
   top  # Linux/macOS
   taskmgr  # Windows
   ```

4. **优化建议 (Optimization Recommendations)**
   - 使用本地网络而非远程连接
   - 使用 SSD 而非 HDD
   - 关闭不必要的后台应用
   - 增加系统可用内存

##### 4. 文件 I/O 错误 (File I/O Errors)

**问题症状 (Symptoms):**
```
[error] Failed to open input file: Permission denied
[error] Cannot create output directory: Permission denied
```

**可能原因 (Possible Causes):**
- 文件权限不足
- 目录不存在
- 磁盘空间不足
- 文件被其他进程占用

**解决方案 (Solutions):**

1. **检查文件权限 (Check File Permissions)**
   ```bash
   # Linux/macOS
   ls -la audio/input/test.mp3
   chmod 644 audio/input/test.mp3
   
   # Windows
   icacls audio\input\test.mp3
   ```

2. **创建必要的目录 (Create Necessary Directories)**
   ```bash
   mkdir -p audio/output  # Linux/macOS
   mkdir audio\output  # Windows
   ```

3. **检查磁盘空间 (Check Disk Space)**
   ```bash
   df -h  # Linux/macOS
   dir  # Windows
   ```

4. **检查文件是否被占用 (Check if File is in Use)**
   ```bash
   # Linux
   lsof | grep test.mp3
   
   # macOS
   lsof | grep test.mp3
   
   # Windows
   handle test.mp3
   ```

##### 5. 协议错误 (Protocol Errors)

**问题症状 (Symptoms):**
```
[error] Protocol error: Invalid message format
[error] Unexpected server response: {"type":"ERROR","message":"..."}
```

**可能原因 (Possible Causes):**
- 客户端和服务器版本不匹配
- 消息格式错误
- 服务器端错误

**解决方案 (Solutions):**

1. **验证版本兼容性 (Verify Version Compatibility)**
   ```bash
   # 检查客户端版本 (Check client version)
   ./audio_stream_client --version
   
   # 检查服务器版本 (Check server version)
   ./audio_stream_server --version
   ```

2. **查看详细日志 (View Detailed Logs)**
   ```bash
   # 启用详细模式 (Enable verbose mode)
   ./audio_stream_client --input audio/input/test.mp3 --verbose
   ```

3. **检查服务器状态 (Check Server Status)**
   ```bash
   # 查看服务器日志 (View server logs)
   tail -f logs/server.log
   ```

#### 调试模式 (Debug Mode)

**启用详细日志 (Enable Verbose Logging):**

```bash
# C++ 客户端 (C++ Client)
./audio_stream_client --input audio/input/test.mp3 --verbose

# Java 客户端 (Java Client)
java -jar audio-stream-client.jar --input audio/input/test.mp3 --verbose
```

**详细模式输出内容 (Verbose Mode Output Includes):**

- WebSocket 连接详情
- 每个消息的发送和接收
- 数据块的详细信息
- 内部状态转换
- 性能计时详情

**示例详细输出 (Example Verbose Output):**

```
[2026-01-24 10:30:15.234] [debug] Connecting to WebSocket: ws://localhost:8080/audio
[2026-01-24 10:30:15.235] [debug] WebSocket handshake initiated
[2026-01-24 10:30:15.236] [debug] WebSocket connection established
[2026-01-24 10:30:15.237] [debug] Sending START message: {"type":"START","streamId":"stream-20260124-103015-a1b2c3d4"}
[2026-01-24 10:30:15.238] [debug] Received server response: {"type":"START_ACK","streamId":"stream-20260124-103015-a1b2c3d4"}
[2026-01-24 10:30:15.239] [debug] Reading chunk 1: offset=0, size=65536
[2026-01-24 10:30:15.240] [debug] Sending binary data: 65536 bytes
[2026-01-24 10:30:15.241] [debug] Chunk 1 sent successfully
...
```

#### 日志文件位置 (Log File Locations)

**C++ 客户端 (C++ Client):**

- **Linux/macOS**: `./logs/client.log` 或 `~/.audio_stream/client.log`
- **Windows**: `.\logs\client.log` 或 `%APPDATA%\audio_stream\client.log`

**Java 客户端 (Java Client):**

- **Linux/macOS**: `./logs/client.log` 或 `~/.audio_stream/client.log`
- **Windows**: `.\logs\client.log` 或 `%APPDATA%\audio_stream\client.log`

**服务器日志 (Server Logs):**

- **Linux/macOS**: `./logs/server.log`
- **Windows**: `.\logs\server.log`

#### 获取帮助 (Getting Help)

如果问题仍未解决，请收集以下信息：

If the issue persists, please collect the following information:

1. **系统信息 (System Information)**
   - 操作系统和版本
   - CPU 和内存规格
   - 网络配置

2. **软件版本 (Software Versions)**
   - 客户端版本
   - 服务器版本
   - 依赖库版本

3. **日志文件 (Log Files)**
   - 客户端日志（启用 --verbose）
   - 服务器日志
   - 系统日志（如果相关）

4. **重现步骤 (Reproduction Steps)**
   - 完整的命令行
   - 输入文件信息
   - 错误消息的完整输出



### 跨平台兼容性 (Cross-Platform Compatibility)

#### 平台特定注意事项 (Platform-Specific Considerations)

##### Windows 平台 (Windows Platform)

**路径处理 (Path Handling):**

```cpp
// C++ - 使用反斜杠或正斜杠 (Use backslash or forward slash)
std::string inputPath = "audio\\input\\test.mp3";  // Windows style
std::string inputPath = "audio/input/test.mp3";    // Cross-platform style (推荐 recommended)

// Java - 使用 File.separator 或正斜杠 (Use File.separator or forward slash)
String inputPath = "audio" + File.separator + "input" + File.separator + "test.mp3";
String inputPath = "audio/input/test.mp3";  // Java 自动转换 (Java auto-converts)
```

**构建命令 (Build Commands):**

```powershell
# C++ 构建 (C++ Build)
.\hello-cpp\build.ps1 -BuildType Release

# Java 构建 (Java Build)
.\hello-java\audio-stream-client\build-client.ps1
```

**执行命令 (Execution Commands):**

```powershell
# C++ 客户端 (C++ Client)
.\hello-cpp\build\bin\audio_stream_client.exe --input audio\input\test.mp3

# Java 客户端 (Java Client)
java -jar hello-java\audio-stream-client\target\audio-stream-client-1.0-SNAPSHOT.jar --input audio\input\test.mp3
```

**特殊注意事项 (Special Considerations):**

1. **文件路径长度限制 (File Path Length Limit)**
   - Windows 默认最大路径长度为 260 字符
   - 可以通过注册表启用长路径支持
   - 建议使用相对路径或短路径

2. **行结束符 (Line Endings)**
   - Windows 使用 CRLF (`\r\n`)
   - 日志文件可能显示不同的行结束符
   - 不影响功能，仅影响文本显示

3. **权限管理 (Permission Management)**
   - 可能需要管理员权限运行
   - 使用 `icacls` 管理文件权限
   - 防火墙可能阻止网络连接

4. **依赖库 (Dependencies)**
   - OpenSSL: 需要安装 Windows 版本
   - Java: 需要 JDK 11 或更高版本
   - Visual Studio: C++ 构建需要 MSVC 编译器

##### Linux 平台 (Linux Platform)

**路径处理 (Path Handling):**

```cpp
// C++ - 使用正斜杠 (Use forward slash)
std::string inputPath = "audio/input/test.mp3";

// Java - 使用正斜杠 (Use forward slash)
String inputPath = "audio/input/test.mp3";
```

**构建命令 (Build Commands):**

```bash
# C++ 构建 (C++ Build)
./hello-cpp/build.sh Release

# Java 构建 (Java Build)
./hello-java/audio-stream-client/build-client.sh
```

**执行命令 (Execution Commands):**

```bash
# C++ 客户端 (C++ Client)
./hello-cpp/build/bin/audio_stream_client --input audio/input/test.mp3

# Java 客户端 (Java Client)
java -jar hello-java/audio-stream-client/target/audio-stream-client-1.0-SNAPSHOT.jar --input audio/input/test.mp3
```

**特殊注意事项 (Special Considerations):**

1. **文件权限 (File Permissions)**
   - 确保可执行文件有执行权限：`chmod +x audio_stream_client`
   - 确保输入文件可读：`chmod 644 audio/input/test.mp3`
   - 确保输出目录可写：`chmod 755 audio/output`

2. **共享库 (Shared Libraries)**
   - 确保 OpenSSL 库已安装：`sudo apt-get install libssl-dev`
   - 检查库路径：`ldconfig -p | grep ssl`
   - 设置 LD_LIBRARY_PATH 如果需要

3. **系统限制 (System Limits)**
   - 检查文件描述符限制：`ulimit -n`
   - 检查内存限制：`ulimit -m`
   - 必要时增加限制：`ulimit -n 4096`

4. **发行版差异 (Distribution Differences)**
   - Ubuntu/Debian: 使用 `apt-get`
   - CentOS/RHEL: 使用 `yum` 或 `dnf`
   - Arch Linux: 使用 `pacman`

##### macOS 平台 (macOS Platform)

**路径处理 (Path Handling):**

```cpp
// C++ - 使用正斜杠 (Use forward slash)
std::string inputPath = "audio/input/test.mp3";

// Java - 使用正斜杠 (Use forward slash)
String inputPath = "audio/input/test.mp3";
```

**构建命令 (Build Commands):**

```bash
# C++ 构建 (C++ Build)
./hello-cpp/build.sh Release

# Java 构建 (Java Build)
./hello-java/audio-stream-client/build-client.sh
```

**执行命令 (Execution Commands):**

```bash
# C++ 客户端 (C++ Client)
./hello-cpp/build/bin/audio_stream_client --input audio/input/test.mp3

# Java 客户端 (Java Client)
java -jar hello-java/audio-stream-client/target/audio-stream-client-1.0-SNAPSHOT.jar --input audio/input/test.mp3
```

**特殊注意事项 (Special Considerations):**

1. **Homebrew 依赖 (Homebrew Dependencies)**
   - 安装 OpenSSL：`brew install openssl`
   - 安装 CMake：`brew install cmake`
   - 设置环境变量：`export OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl`

2. **Xcode 命令行工具 (Xcode Command Line Tools)**
   - 安装：`xcode-select --install`
   - 验证：`xcode-select -p`

3. **文件系统 (File System)**
   - macOS 默认文件系统不区分大小写（APFS 可配置）
   - 注意文件名大小写问题
   - 使用 `diskutil` 检查文件系统类型

4. **安全和隐私 (Security and Privacy)**
   - 可能需要授予终端完全磁盘访问权限
   - 系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问权限
   - 防火墙可能阻止网络连接

#### 路径处理最佳实践 (Path Handling Best Practices)

**推荐做法 (Recommended Practices):**

1. **使用正斜杠 (Use Forward Slashes)**
   ```cpp
   // ✓ 推荐 (Recommended) - 跨平台兼容 (Cross-platform compatible)
   std::string path = "audio/input/test.mp3";
   
   // ✗ 不推荐 (Not recommended) - 仅 Windows (Windows only)
   std::string path = "audio\\input\\test.mp3";
   ```

2. **使用路径库 (Use Path Libraries)**
   ```cpp
   // C++ - 使用 std::filesystem (Use std::filesystem)
   #include <filesystem>
   namespace fs = std::filesystem;
   fs::path inputPath = fs::path("audio") / "input" / "test.mp3";
   
   // Java - 使用 Path API (Use Path API)
   import java.nio.file.Path;
   import java.nio.file.Paths;
   Path inputPath = Paths.get("audio", "input", "test.mp3");
   ```

3. **规范化路径 (Normalize Paths)**
   ```cpp
   // C++ - 规范化路径 (Normalize path)
   fs::path normalized = fs::canonical(inputPath);
   
   // Java - 规范化路径 (Normalize path)
   Path normalized = inputPath.normalize();
   ```

4. **处理相对路径 (Handle Relative Paths)**
   ```cpp
   // C++ - 转换为绝对路径 (Convert to absolute path)
   fs::path absolute = fs::absolute(inputPath);
   
   // Java - 转换为绝对路径 (Convert to absolute path)
   Path absolute = inputPath.toAbsolutePath();
   ```

#### 字符编码 (Character Encoding)

**文件名编码 (Filename Encoding):**

- **Windows**: UTF-16 (宽字符 wide characters)
- **Linux**: UTF-8
- **macOS**: UTF-8 (NFD 规范化 NFD normalization)

**处理建议 (Handling Recommendations):**

```cpp
// C++ - 使用 UTF-8 编码 (Use UTF-8 encoding)
#include <codecvt>
#include <locale>

std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
std::wstring wide = converter.from_bytes(utf8String);
std::string utf8 = converter.to_bytes(wideString);
```

```java
// Java - 默认使用 UTF-8 (Default to UTF-8)
String filename = new String(bytes, StandardCharsets.UTF_8);
byte[] bytes = filename.getBytes(StandardCharsets.UTF_8);
```

#### 网络配置 (Network Configuration)

**防火墙规则 (Firewall Rules):**

**Windows:**
```powershell
# 允许入站连接 (Allow inbound connections)
netsh advfirewall firewall add rule name="Audio Stream Server" dir=in action=allow protocol=TCP localport=8080

# 允许出站连接 (Allow outbound connections)
netsh advfirewall firewall add rule name="Audio Stream Client" dir=out action=allow protocol=TCP remoteport=8080
```

**Linux (iptables):**
```bash
# 允许入站连接 (Allow inbound connections)
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# 允许出站连接 (Allow outbound connections)
sudo iptables -A OUTPUT -p tcp --dport 8080 -j ACCEPT

# 保存规则 (Save rules)
sudo iptables-save > /etc/iptables/rules.v4
```

**Linux (firewalld):**
```bash
# 允许端口 (Allow port)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

**macOS:**
```bash
# 检查防火墙状态 (Check firewall status)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# 允许应用 (Allow application)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/audio_stream_client
```

#### 性能调优 (Performance Tuning)

**平台特定优化 (Platform-Specific Optimizations):**

**Windows:**
- 禁用 Windows Defender 实时扫描（测试时）
- 使用高性能电源计划
- 禁用 Windows 搜索索引（测试目录）

**Linux:**
- 调整 TCP 缓冲区大小：`sysctl -w net.core.rmem_max=16777216`
- 禁用 CPU 频率缩放：`cpupower frequency-set -g performance`
- 使用 `ionice` 提高 I/O 优先级

**macOS:**
- 禁用 Spotlight 索引（测试目录）
- 使用 `caffeinate` 防止系统休眠
- 关闭节能模式

各语言 mmap 库的总结：                                      
                                                                                  
  各语言 mmap 库总结                                                              
  语言: Python                                                                    
  库/方案: mmap (标准库)                                                          
  类型: 内置                                                                      
  说明: Python 标准库提供的高层 mmap 接口                                         
  ────────────────────────────────────────                                        
  语言: C++                                                                       
  库/方案: <sys/mman.h> / <windows.h>                                             
  类型: 原生 API                                                                  
  说明: 直接调用操作系统 mmap 系统调用                                            
  ────────────────────────────────────────                                        
  语言: C#                                                                        
  库/方案: System.IO.MemoryMappedFiles                                            
  类型: .NET 内置                                                                 
  说明: .NET Core 原生支持的内存映射文件                                          
  ────────────────────────────────────────                                        
  语言: Java                                                                      
  库/方案: java.nio.MappedByteBuffer                                              
  类型: Java 内置                                                                 
  说明: Java NIO 提供的内存映射缓冲区                                             
  ────────────────────────────────────────                                        
  语言: Kotlin                                                                    
  库/方案: JNA (net.java.dev.jna:jna)                                             
  类型: 第三方                                                                    
  说明: 通过 JNA (Java Native Access) 调用原生 mmap                               
  ────────────────────────────────────────                                        
  语言: Go                                                                        
  库/方案: os 包                                                                  
  类型: 标准库                                                                    
  说明: 使用文件操作实现类似 mmap 行为                                            
  ────────────────────────────────────────                                        
  语言: Rust                                                                      
  库/方案: std::fs / std::os                                                      
  类型: 标准库                                                                    
  说明: 标准库提供的安全文件操作                                                  
  ────────────────────────────────────────                                        
  语言: Swift                                                                     
  库/方案: Foundation.FileHandle                                                  
  类型: 框架                                                                      
  说明: Swift Foundation 提供的原生文件处理                                       
  ────────────────────────────────────────                                        
  语言: Node.js                                                                   
  库/方案: mmap-io                                                                
  类型: npm                                                                       
  说明: Node.js 没有内置 mmap，使用第三方库                                       
  ────────────────────────────────────────                                        
  语言: TypeScript                                                                
  库/方案: mmap-io                                                                
  类型: npm                                                                       
  说明: 与 Node.js 共享相同的 mmap 库                                             
  ────────────────────────────────────────                                        
  语言: Dart                                                                      
  库/方案: dart:ffi                                                               
  类型: FFI                                                                       
  说明: 通过 Dart FFI 调用原生 C mmap 函数                                        
  ────────────────────────────────────────                                        
  语言: PHP                                                                       
  库/方案: 文件流操作                                                             
  类型: 标准库                                                                    
  说明: PHP 无直接 mmap，使用标准文件操作                                         
  分类                                                                            
                                                                                  
  - 原生内置支持: Python, Java, C#, Go, Rust, Swift                               
  - 第三方库: Node.js/TypeScript (mmap-io), Kotlin (JNA)                          
  - 直接系统调用: C++                                                             
  - FFI 调用: Dart                                                                
  - 无 mmap: PHP                                                                  
                                                