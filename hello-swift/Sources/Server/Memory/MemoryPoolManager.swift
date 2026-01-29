//
//  MemoryPoolManager.swift
//  Audio Stream Server
//
//  Memory pool manager for efficient buffer reuse.
//  Pre-allocates buffers to minimize allocation overhead.
//  Implemented as a singleton to ensure a single shared pool across all streams.
//  Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.
//

import Foundation
import AudioStreamCommon

/// Memory pool manager singleton.
class MemoryPoolManager {
    private static var instance: MemoryPoolManager?
    private let bufferSize: Int
    private let poolSize: Int
    private var availableBuffers: [Data]
    private var totalBuffers: Int
    private let lock = NSLock()

    /// Get the singleton instance of MemoryPoolManager.
    static func getInstance(bufferSize: Int = 65536, poolSize: Int = 100) -> MemoryPoolManager {
        if let instance = instance {
            return instance
        }

        let newInstance = MemoryPoolManager(bufferSize: bufferSize, poolSize: poolSize)
        instance = newInstance
        return newInstance
    }

    /// Private constructor for singleton pattern.
    private init(bufferSize: Int, poolSize: Int) {
        self.bufferSize = bufferSize
        self.poolSize = poolSize
        self.availableBuffers = []
        self.totalBuffers = 0

        // Pre-allocate buffers
        for _ in 0..<poolSize {
            let buffer = Data(repeating: 0, count: bufferSize)
            availableBuffers.append(buffer)
            totalBuffers += 1
        }

        Logger.info("MemoryPoolManager initialized with \(poolSize) buffers of \(bufferSize) bytes")
    }

    /// Acquire a buffer from the pool.
    /// If pool is exhausted, allocates a new buffer dynamically.
    func acquireBuffer() -> Data {
        lock.lock()
        defer { lock.unlock() }

        if !availableBuffers.isEmpty {
            let buffer = availableBuffers.removeFirst()
            Logger.debug("Acquired buffer from pool (\(availableBuffers.count) remaining)")
            return buffer
        } else {
            // Pool exhausted, allocate new buffer
            let buffer = Data(repeating: 0, count: bufferSize)
            totalBuffers += 1
            Logger.debug("Pool exhausted, allocated new buffer (total: \(totalBuffers))")
            return buffer
        }
    }

    /// Release a buffer back to the pool.
    func releaseBuffer(_ buffer: Data) {
        if buffer.count != bufferSize {
            Logger.warn("Buffer size mismatch: expected \(bufferSize), got \(buffer.count)")
            return
        }

        lock.lock()
        defer { lock.unlock() }

        // Clear buffer before returning to pool
        let cleared = Data(repeating: 0, count: bufferSize)

        // Only return to pool if we haven't exceeded pool size
        if availableBuffers.count < poolSize {
            availableBuffers.append(cleared)
        }

        Logger.debug("Released buffer to pool (\(availableBuffers.count) available)")
    }

    /// Get the number of available buffers in the pool.
    func getAvailableBuffers() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return availableBuffers.count
    }

    /// Get the total number of buffers (available + in-use).
    func getTotalBuffers() -> Int {
        return poolSize
    }

    /// Get the buffer size.
    func getBufferSize() -> Int {
        return bufferSize
    }
}
