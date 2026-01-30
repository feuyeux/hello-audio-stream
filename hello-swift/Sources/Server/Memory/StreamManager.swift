//
//  StreamManager.swift
//  Audio Stream Server
//
//  Stream manager for managing active audio streams.
//  Thread-safe registry of stream contexts.
//  Matches Python StreamManager and Java StreamManager functionality.
//

import AudioStreamCommon
import Foundation

/// Stream manager for managing multiple concurrent streams.
class StreamManager {
    nonisolated(unsafe) private static var instance: StreamManager?
    private let cacheDirectory: String
    private var streams: [String: StreamContext] = [:]
    private let lock = NSLock()

    /// Get the singleton instance of StreamManager.
    static func getInstance(cacheDirectory: String = "cache") -> StreamManager {
        if let instance = instance {
            return instance
        }

        let newInstance = StreamManager(cacheDirectory: cacheDirectory)
        instance = newInstance
        return newInstance
    }

    /// Private constructor for singleton pattern.
    private init(cacheDirectory: String) {
        self.cacheDirectory = cacheDirectory

        // Create cache directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: cacheDirectory) {
            try? fileManager.createDirectory(
                atPath: cacheDirectory, withIntermediateDirectories: true)
        }

        Logger.info("StreamManager initialized with cache directory: \(cacheDirectory)")
    }

    /// Create a new stream.
    func createStream(streamId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Check if stream already exists
        if streams[streamId] != nil {
            Logger.warn("Stream already exists: \(streamId)")
            return false
        }

        // Create new stream context
        let cachePath = getCachePath(streamId: streamId)
        let context = StreamContext(streamId: streamId, cachePath: cachePath)
        context.status = .uploading
        context.updateAccessTime()

        // Create memory-mapped cache file
        let mmapFile = MemoryMappedCache(path: cachePath)
        if !mmapFile.create(filePath: cachePath, initialSize: 0) {
            return false
        }
        context.mmapFile = mmapFile

        // Add to registry
        streams[streamId] = context

        Logger.info("Created stream: \(streamId) at path: \(cachePath)")
        return true
    }

    /// Get a stream context.
    func getStream(streamId: String) -> StreamContext? {
        lock.lock()
        defer { lock.unlock() }

        let context = streams[streamId]
        context?.updateAccessTime()
        return context
    }

    /// Delete a stream.
    func deleteStream(streamId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let context = streams[streamId] else {
            Logger.warn("Stream not found for deletion: \(streamId)")
            return false
        }

        // Close memory-mapped file
        context.mmapFile?.close()

        // Remove cache file
        if FileManager.default.fileExists(atPath: context.cachePath) {
            try? FileManager.default.removeItem(atPath: context.cachePath)
        }

        // Remove from registry
        streams.removeValue(forKey: streamId)

        Logger.info("Deleted stream: \(streamId)")
        return true
    }

    /// List all active streams.
    func listActiveStreams() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(streams.keys)
    }

    /// Write a chunk of data to a stream.
    func writeChunk(streamId: String, data: Data) -> Bool {
        guard let stream = getStream(streamId: streamId) else {
            Logger.error("Stream not found for write: \(streamId)")
            return false
        }

        stream.lock.lock()
        defer { stream.lock.unlock() }

        if stream.status != .uploading {
            Logger.error("Stream \(streamId) is not in uploading state")
            return false
        }

        // Write data to memory-mapped file
        guard let mmapFile = stream.mmapFile else {
            Logger.error("No mmap file for stream \(streamId)")
            return false
        }

        let written = mmapFile.write(offset: stream.currentOffset, data: data)

        if written > 0 {
            stream.currentOffset += Int64(written)
            stream.totalSize += Int64(written)
            stream.updateAccessTime()

            Logger.debug(
                "Wrote \(written) bytes to stream \(streamId) at offset \(stream.currentOffset - Int64(written))"
            )
            return true
        } else {
            Logger.error("Failed to write data to stream \(streamId)")
            return false
        }
    }

    /// Read a chunk of data from a stream.
    func readChunk(streamId: String, offset: Int64, length: Int) -> Data {
        Logger.info("readChunk called: streamId=\(streamId), offset=\(offset), length=\(length)")
        
        guard let stream = getStream(streamId: streamId) else {
            Logger.error("Stream not found for read: \(streamId)")
            return Data()
        }

        stream.lock.lock()
        defer { stream.lock.unlock() }

        Logger.info("Stream status: \(stream.status), totalSize: \(stream.totalSize)")

        // Read data from memory-mapped file
        guard let mmapFile = stream.mmapFile else {
            Logger.error("No mmap file for stream \(streamId)")
            return Data()
        }

        Logger.info("Calling mmapFile.read...")
        let data = mmapFile.read(offset: offset, length: length)
        stream.updateAccessTime()

        Logger.info("Read \(data.count) bytes from stream \(streamId) at offset \(offset)")
        return data
    }

    /// Finalize a stream.
    func finalizeStream(streamId: String) -> Bool {
        guard let stream = getStream(streamId: streamId) else {
            Logger.error("Stream not found for finalization: \(streamId)")
            return false
        }

        stream.lock.lock()
        defer { stream.lock.unlock() }

        if stream.status != .uploading {
            Logger.warn("Stream \(streamId) is not in uploading state for finalization")
            return false
        }

        // Finalize memory-mapped file
        guard let mmapFile = stream.mmapFile else {
            Logger.error("No mmap file for stream \(streamId)")
            return false
        }

        if mmapFile.finalize(finalSize: stream.totalSize) {
            stream.status = .ready
            stream.updateAccessTime()

            Logger.info("Finalized stream: \(streamId) with \(stream.totalSize) bytes")
            return true
        } else {
            Logger.error("Failed to finalize memory-mapped file for stream \(streamId)")
            return false
        }
    }

    /// Clean up old streams (older than maxAgeHours).
    func cleanupOldStreams(maxAgeHours: Int = 24) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let cutoff = TimeInterval(maxAgeHours * 3600)

        let toRemove = streams.filter { _, context in
            let age = now.timeIntervalSince(context.lastAccessedAt)
            return age > cutoff
        }.map { (id, _) in id }

        for streamId in toRemove {
            Logger.info("Cleaning up old stream: \(streamId)")
            _ = deleteStream(streamId: streamId)
        }
    }

    /// Get cache file path for a stream.
    private func getCachePath(streamId: String) -> String {
        return "\(cacheDirectory)/\(streamId).cache"
    }
}
