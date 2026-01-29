package org.feuyeux.mmap.audio.server.memory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Memory pool manager for efficient buffer reuse.
 * Pre-allocates buffers to minimize allocation overhead.
 * Implemented as a singleton to ensure a single shared pool across all streams.
 * Matches C++ MemoryPoolManager functionality and lifecycle.
 */
public class MemoryPoolManager {
    private static final Logger logger = LoggerFactory.getLogger(MemoryPoolManager.class);

    private static volatile MemoryPoolManager instance;
    private static final ReentrantLock instanceLock = new ReentrantLock();

    private final int bufferSize;
    private final int poolSize;
    private final Queue<ByteBuffer> availableBuffers;
    private final ReentrantLock mutex;

    /**
     * Get the singleton instance of MemoryPoolManager.
     *
     * @param bufferSize size of each buffer in bytes
     * @param poolSize   number of buffers to pre-allocate
     * @return the singleton instance
     */
    public static MemoryPoolManager getInstance(int bufferSize, int poolSize) {
        if (instance == null) {
            instanceLock.lock();
            try {
                if (instance == null) {
                    instance = new MemoryPoolManager(bufferSize, poolSize);
                }
            } finally {
                instanceLock.unlock();
            }
        }
        return instance;
    }

    /**
     * Get the singleton instance with default parameters.
     *
     * @return the singleton instance
     */
    public static MemoryPoolManager getInstance() {
        return getInstance(65536, 100); // Default: 64KB buffers, 100 buffers
    }

    /**
     * Private constructor for singleton pattern.
     *
     * @param bufferSize size of each buffer in bytes
     * @param poolSize   number of buffers to pre-allocate
     */
    private MemoryPoolManager(int bufferSize, int poolSize) {
        this.bufferSize = bufferSize;
        this.poolSize = poolSize;
        this.availableBuffers = new ConcurrentLinkedQueue<>();
        this.mutex = new ReentrantLock();

        // Pre-allocate buffers
        for (int i = 0; i < poolSize; i++) {
            availableBuffers.offer(ByteBuffer.allocateDirect(bufferSize));
        }

        logger.info("MemoryPoolManager initialized with {} buffers of {} bytes", poolSize, bufferSize);
    }

    /**
     * Acquire a buffer from the pool.
     *
     * @return a buffer, or a new buffer if pool is exhausted
     */
    public ByteBuffer acquireBuffer() {
        mutex.lock();
        try {
            ByteBuffer buffer = availableBuffers.poll();
            
            if (buffer == null) {
                // Pool exhausted, allocate new buffer
                logger.warn("Memory pool exhausted, allocating new buffer");
                return ByteBuffer.allocateDirect(bufferSize);
            }

            buffer.clear();
            return buffer;

        } finally {
            mutex.unlock();
        }
    }

    /**
     * Release a buffer back to the pool.
     *
     * @param buffer the buffer to release
     */
    public void releaseBuffer(ByteBuffer buffer) {
        if (buffer == null) {
            return;
        }

        mutex.lock();
        try {
            // Only return to pool if we haven't exceeded pool size
            if (availableBuffers.size() < poolSize) {
                buffer.clear();
                availableBuffers.offer(buffer);
            }
        } finally {
            mutex.unlock();
        }
    }

    /**
     * Get the number of available buffers.
     *
     * @return number of available buffers
     */
    public int getAvailableBuffers() {
        mutex.lock();
        try {
            return availableBuffers.size();
        } finally {
            mutex.unlock();
        }
    }

    /**
     * Get the total number of buffers in the pool.
     *
     * @return total pool size
     */
    public int getTotalBuffers() {
        return poolSize;
    }
}
