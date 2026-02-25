import Foundation

/// Stream lifecycle status.
enum StreamStatus: String {
    case uploading = "UPLOADING"
    case ready = "READY"
    case error = "ERROR"
}

/// Per-stream state.
class Stream {
    let id: String
    let cache: MmapCache
    var offset: Int64 = 0
    let created: Date
    var lastAccess: Date
    var status: StreamStatus = .uploading
    let lock = NSLock()

    init(id: String, cache: MmapCache) {
        self.id = id
        self.cache = cache
        self.created = Date()
        self.lastAccess = Date()
    }

    func touch() { lastAccess = Date() }
}

/// Thread-safe stream registry with cleanup.
class StreamManager: @unchecked Sendable {
    static let maxStreams = 1000
    private let cacheDir: String
    private var streams: [String: Stream] = [:]
    private let lock = NSLock()

    init(cacheDir: String = "cache") {
        self.cacheDir = cacheDir
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDir) {
            try? fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        }
    }

    func create(_ id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        if streams[id] != nil { throw StreamError.alreadyExists(id) }
        if streams.count >= Self.maxStreams { throw StreamError.limitReached }

        let path = "\(cacheDir)/\(id).cache"
        let cache = MmapCache(path: path)
        guard cache.create(initialSize: 64 * 1024 * 1024) else {
            throw StreamError.cacheCreateFailed(id)
        }
        streams[id] = Stream(id: id, cache: cache)
        print("[StreamManager] created stream: \(id)")
    }

    func write(_ id: String, _ data: Data) throws {
        let stream = try getStream(id)
        stream.lock.lock()
        defer { stream.lock.unlock() }

        guard stream.status == .uploading else { throw StreamError.notUploading(id) }
        let written = stream.cache.write(offset: stream.offset, data: data)
        stream.offset += Int64(written)
        stream.touch()
    }

    func complete(_ id: String) throws {
        let stream = try getStream(id)
        stream.lock.lock()
        defer { stream.lock.unlock() }

        guard stream.status == .uploading else { throw StreamError.notUploading(id) }
        guard stream.cache.finalize(finalSize: stream.offset) else {
            throw StreamError.finalizeFailed(id)
        }
        stream.status = .ready
        stream.touch()
        print("[StreamManager] completed stream: \(id) (\(stream.offset) bytes)")
    }

    func read(_ id: String, offset: Int64, length: Int) throws -> Data {
        let stream = try getStream(id)
        stream.lock.lock()
        defer { stream.lock.unlock() }

        stream.touch()
        return stream.cache.read(offset: offset, length: length)
    }

    func delete(_ id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let stream = streams.removeValue(forKey: id) else {
            throw StreamError.notFound(id)
        }
        stream.cache.close()
        try? FileManager.default.removeItem(atPath: stream.cache.path)
        print("[StreamManager] deleted stream: \(id)")
    }

    func markError(_ id: String) {
        lock.lock()
        defer { lock.unlock() }

        if let stream = streams[id], stream.status == .uploading {
            stream.status = .error
            print("[StreamManager] marked ERROR: \(id)")
        }
    }

    func statusOf(_ id: String) throws -> (StreamStatus, Int64) {
        let stream = try getStream(id)
        stream.lock.lock()
        defer { stream.lock.unlock() }
        return (stream.status, stream.offset)
    }

    func list() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(streams.keys)
    }

    func cleanup() {
        lock.lock()
        let snapshot = streams
        lock.unlock()

        let now = Date()
        let maxIdleHours: TimeInterval = 24 * 3600
        let maxUploadingHours: TimeInterval = 1 * 3600

        for (id, stream) in snapshot {
            let idle = now.timeIntervalSince(stream.lastAccess)
            let shouldRemove: Bool
            if stream.status == .uploading {
                shouldRemove = idle > maxUploadingHours
            } else if stream.status == .error {
                shouldRemove = true
            } else {
                shouldRemove = idle > maxIdleHours
            }

            if shouldRemove {
                lock.lock()
                streams.removeValue(forKey: id)
                lock.unlock()
                stream.cache.close()
                try? FileManager.default.removeItem(atPath: stream.cache.path)
                print("[StreamManager] cleaned up: \(id)")
            }
        }
    }

    func stats() -> (count: Int, totalBytes: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let total = streams.values.reduce(Int64(0)) { $0 + $1.offset }
        return (streams.count, total)
    }

    // MARK: - Private

    private func getStream(_ id: String) throws -> Stream {
        lock.lock()
        defer { lock.unlock() }
        guard let stream = streams[id] else { throw StreamError.notFound(id) }
        return stream
    }
}

enum StreamError: Error, CustomStringConvertible {
    case notFound(String)
    case alreadyExists(String)
    case limitReached
    case notUploading(String)
    case cacheCreateFailed(String)
    case finalizeFailed(String)

    var description: String {
        switch self {
        case .notFound(let id): return "Stream not found: \(id)"
        case .alreadyExists(let id): return "Stream already exists: \(id)"
        case .limitReached: return "Max streams limit reached"
        case .notUploading(let id): return "Stream not in uploading state: \(id)"
        case .cacheCreateFailed(let id): return "Failed to create cache for: \(id)"
        case .finalizeFailed(let id): return "Failed to finalize: \(id)"
        }
    }
}
