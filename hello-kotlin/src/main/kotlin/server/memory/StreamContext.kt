// Stream context for managing active audio streams.
// Contains stream metadata and cache file handle.
// Matches Python StreamContext and Java StreamContext functionality.

package server.memory

import java.time.Instant

/**
 * Stream status enumeration
 */
enum class StreamStatus {
    UPLOADING,
    READY,
    ERROR
}

/**
 * Stream context containing metadata and state for a single stream.
 */
class StreamContext(
    val streamId: String,
    var cachePath: String = ""
) {
    var mmapFile: MemoryMappedCache? = null
    var currentOffset: Long = 0
    var totalSize: Long = 0
    val createdAt: Instant = Instant.now()
    var lastAccessedAt: Instant = createdAt
    var status: StreamStatus = StreamStatus.UPLOADING

    /**
     * Update last accessed timestamp
     */
    fun updateAccessTime() {
        lastAccessedAt = Instant.now()
    }
}
