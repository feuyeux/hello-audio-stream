//
//  StreamContext.swift
//  Audio Stream Server
//
//  Stream context for managing active audio streams.
//  Contains stream metadata and cache file handle.
//  Matches Python StreamContext and Java StreamContext functionality.
//

import AudioStreamCommon
import Foundation

/// Stream status enumeration
enum StreamStatus: String {
    case uploading = "UPLOADING"
    case ready = "READY"
    case error = "ERROR"
}

/// Stream context containing metadata and state for a single stream.
class StreamContext {
    var streamId: String
    var cachePath: String
    var mmapFile: MemoryMappedCache?
    var currentOffset: Int64
    var totalSize: Int64
    var createdAt: Date
    var lastAccessedAt: Date
    var status: StreamStatus

    /// Lock for thread-safe access to this stream context
    let lock = NSLock()

    /// Create a new StreamContext.
    init(streamId: String, cachePath: String = "") {
        self.streamId = streamId
        self.cachePath = cachePath
        self.mmapFile = nil
        self.currentOffset = 0
        self.totalSize = 0
        let now = Date()
        self.createdAt = now
        self.lastAccessedAt = now
        self.status = .uploading
    }

    /// Update last accessed timestamp
    func updateAccessTime() {
        lastAccessedAt = Date()
    }
}
