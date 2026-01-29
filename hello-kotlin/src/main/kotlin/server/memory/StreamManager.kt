// Stream manager for managing active audio streams.
// Thread-safe registry of stream contexts.
// Matches Python StreamManager and Java StreamManager functionality.

package server.memory

import server.Logger
import java.io.File
import java.time.Instant

/**
 * Stream manager for managing multiple concurrent streams.
 */
class StreamManager private constructor(private val cacheDirectory: String) {
    private val streams: MutableMap<String, StreamContext> = mutableMapOf()

    companion object {
        @Volatile
        private var instance: StreamManager? = null

        /**
         * Get the singleton instance of StreamManager.
         */
        fun getInstance(cacheDirectory: String = "cache"): StreamManager {
            return instance ?: synchronized(this) {
                instance ?: StreamManager(cacheDirectory).also {
                    instance = it
                }
            }
        }
    }

    init {
        // Create cache directory if it doesn't exist
        File(cacheDirectory).mkdirs()

        Logger.info("StreamManager initialized with cache directory: $cacheDirectory")
    }

    /**
     * Create a new stream.
     */
    fun createStream(streamId: String): Boolean {
        synchronized(streams) {
            // Check if stream already exists
            if (streams.containsKey(streamId)) {
                Logger.warning("Stream already exists: $streamId")
                return false
            }

            try {
                // Create new stream context
                val cachePath = getCachePath(streamId)
                val context = StreamContext(streamId, cachePath)
                context.status = StreamStatus.UPLOADING
                context.updateAccessTime()

                // Create memory-mapped cache file
                val mmapFile = MemoryMappedCache(cachePath)
                if (!mmapFile.create()) {
                    return false
                }
                context.mmapFile = mmapFile

                // Add to registry
                streams[streamId] = context

                Logger.info("Created stream: $streamId at path: $cachePath")
                return true
            } catch (e: Exception) {
                Logger.error("Failed to create stream $streamId: ${e.message}")
                return false
            }
        }
    }

    /**
     * Get a stream context.
     */
    fun getStream(streamId: String): StreamContext? {
        return synchronized(streams) {
            val context = streams[streamId]
            context?.updateAccessTime()
            context
        }
    }

    /**
     * Delete a stream.
     */
    fun deleteStream(streamId: String): Boolean {
        synchronized(streams) {
            val context = streams[streamId]
            if (context == null) {
                Logger.warning("Stream not found for deletion: $streamId")
                return false
            }

            try {
                // Close memory-mapped file
                context.mmapFile?.close()

                // Remove cache file
                File(context.cachePath).delete()

                // Remove from registry
                streams.remove(streamId)

                Logger.info("Deleted stream: $streamId")
                return true
            } catch (e: Exception) {
                Logger.error("Failed to delete stream $streamId: ${e.message}")
                return false
            }
        }
    }

    /**
     * List all active streams.
     */
    fun listActiveStreams(): List<String> {
        return synchronized(streams) {
            streams.keys.toList()
        }
    }

    /**
     * Write a chunk of data to a stream.
     */
    fun writeChunk(streamId: String, data: ByteArray): Boolean {
        val stream = getStream(streamId)
        if (stream == null) {
            Logger.error("Stream not found for write: $streamId")
            return false
        }

        if (stream.status != StreamStatus.UPLOADING) {
            Logger.error("Stream $streamId is not in uploading state")
            return false
        }

        return try {
            // Write data to memory-mapped file
            val mmapFile = stream.mmapFile
            if (mmapFile == null) {
                return false
            }

            val written = mmapFile.write(stream.currentOffset, data)

            if (written > 0) {
                stream.currentOffset += written
                stream.totalSize += written
                stream.updateAccessTime()

                Logger.debug("Wrote $written bytes to stream $streamId at offset ${stream.currentOffset - written}")
                true
            } else {
                Logger.error("Failed to write data to stream $streamId")
                false
            }
        } catch (e: Exception) {
            Logger.error("Error writing to stream $streamId: ${e.message}")
            false
        }
    }

    /**
     * Read a chunk of data from a stream.
     */
    fun readChunk(streamId: String, offset: Long, length: Int): ByteArray {
        val stream = getStream(streamId)
        if (stream == null) {
            Logger.error("Stream not found for read: $streamId")
            return byteArrayOf()
        }

        return try {
            // Read data from memory-mapped file
            val mmapFile = stream.mmapFile
            if (mmapFile == null) {
                return byteArrayOf()
            }

            val data = mmapFile.read(offset, length)
            stream.updateAccessTime()

            Logger.debug("Read ${data.size} bytes from stream $streamId at offset $offset")
            data
        } catch (e: Exception) {
            Logger.error("Error reading from stream $streamId: ${e.message}")
            byteArrayOf()
        }
    }

    /**
     * Finalize a stream.
     */
    fun finalizeStream(streamId: String): Boolean {
        val stream = getStream(streamId)
        if (stream == null) {
            Logger.error("Stream not found for finalization: $streamId")
            return false
        }

        if (stream.status != StreamStatus.UPLOADING) {
            Logger.warning("Stream $streamId is not in uploading state for finalization")
            return false
        }

        return try {
            // Finalize memory-mapped file
            val mmapFile = stream.mmapFile
            if (mmapFile == null) {
                return false
            }

            if (mmapFile.finalize(stream.totalSize)) {
                stream.status = StreamStatus.READY
                stream.updateAccessTime()

                Logger.info("Finalized stream: $streamId with ${stream.totalSize} bytes")
                true
            } else {
                Logger.error("Failed to finalize memory-mapped file for stream $streamId")
                false
            }
        } catch (e: Exception) {
            Logger.error("Error finalizing stream $streamId: ${e.message}")
            false
        }
    }

    /**
     * Clean up old streams (older than maxAgeHours).
     */
    fun cleanupOldStreams(maxAgeHours: Int = 24) {
        val now = Instant.now()
        val cutoffHours = maxAgeHours.toLong()
        val cutoffSeconds = cutoffHours * 3600

        val toRemove = synchronized(streams) {
            streams.filter { (_, context) ->
                val age = java.time.Duration.between(context.lastAccessedAt, now).seconds
                age > cutoffSeconds
            }.keys.toList()
        }

        for (streamId in toRemove) {
            Logger.info("Cleaning up old stream: $streamId")
            deleteStream(streamId)
        }
    }

    /**
     * Get cache file path for a stream.
     */
    private fun getCachePath(streamId: String): String {
        return "$cacheDirectory/$streamId.cache"
    }
}
