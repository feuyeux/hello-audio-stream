package client.core

/**
 * Chunk management for file streams
 */
object ChunkManager {
    const val UPLOAD_CHUNK_SIZE = 8192 // 8KB to avoid WebSocket frame fragmentation
    const val DOWNLOAD_CHUNK_SIZE = 8192 // 8KB per GET request
    
    /**
     * Calculate the number of chunks needed for a file
     */
    fun calculateChunkCount(fileSize: Long, chunkSize: Int): Int {
        return ((fileSize + chunkSize - 1) / chunkSize).toInt()
    }
    
    /**
     * Calculate the size of a specific chunk
     */
    fun calculateChunkSize(fileSize: Long, chunkIndex: Int, chunkSize: Int): Int {
        val offset = chunkIndex.toLong() * chunkSize
        return minOf(chunkSize.toLong(), fileSize - offset).toInt()
    }
    
    /**
     * Calculate the offset for a specific chunk
     */
    fun calculateChunkOffset(chunkIndex: Int, chunkSize: Int): Long {
        return chunkIndex.toLong() * chunkSize
    }
}
