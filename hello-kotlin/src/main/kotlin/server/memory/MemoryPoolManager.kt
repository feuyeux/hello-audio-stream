// Memory pool manager for efficient buffer reuse.
// Pre-allocates buffers to minimize allocation overhead.
// Implemented as a singleton to ensure a single shared pool across all streams.
// Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.

package server.memory

import server.Logger

/**
 * Memory pool manager singleton.
 */
class MemoryPoolManager private constructor(
    private val bufferSize: Int,
    private val poolSize: Int
) {
    companion object {
        @Volatile
        private var instance: MemoryPoolManager? = null

        /**
         * Get the singleton instance of MemoryPoolManager.
         */
        fun getInstance(bufferSize: Int = 65536, poolSize: Int = 100): MemoryPoolManager {
            return instance ?: synchronized(this) {
                instance ?: MemoryPoolManager(bufferSize, poolSize).also {
                    instance = it
                }
            }
        }
    }

    private val availableBuffers: ArrayDeque<ByteArray> = ArrayDeque()
    private var totalBuffersCount: Int = 0
    private val lock = Any()

    init {
        // Pre-allocate buffers
        for (i in 0 until poolSize) {
            val buffer = ByteArray(bufferSize)
            availableBuffers.addLast(buffer)
            totalBuffersCount++
        }

        Logger.info("MemoryPoolManager initialized with $poolSize buffers of $bufferSize bytes")
    }

    /**
     * Acquire a buffer from the pool.
     * If pool is exhausted, allocates a new buffer dynamically.
     */
    fun acquireBuffer(): ByteArray {
        return synchronized(lock) {
            if (availableBuffers.isNotEmpty()) {
                val buffer = availableBuffers.removeFirst()
                Logger.debug("Acquired buffer from pool (${availableBuffers.size} remaining)")
                buffer
            } else {
                // Pool exhausted, allocate new buffer
                val buffer = ByteArray(bufferSize)
                totalBuffersCount++
                Logger.debug("Pool exhausted, allocated new buffer (total: $totalBuffersCount)")
                buffer
            }
        }
    }

    /**
     * Release a buffer back to the pool.
     */
    fun releaseBuffer(buffer: ByteArray) {
        if (buffer.size != bufferSize) {
            Logger.warning("Buffer size mismatch: expected $bufferSize, got ${buffer.size}")
            return
        }

        synchronized(lock) {
            // Clear buffer before returning to pool
            buffer.fill(0)

            // Only return to pool if we haven't exceeded pool size
            if (availableBuffers.size < poolSize) {
                availableBuffers.addLast(buffer)
            }

            Logger.debug("Released buffer to pool (${availableBuffers.size} available)")
        }
    }

    /**
     * Get the number of available buffers in the pool.
     */
    fun getAvailableBuffers(): Int {
        return synchronized(lock) {
            availableBuffers.size
        }
    }

    /**
     * Get the total number of buffers (available + in-use).
     */
    fun getTotalBuffers(): Int = poolSize

    /**
     * Get the buffer size.
     */
    fun getBufferSize(): Int = bufferSize
}
