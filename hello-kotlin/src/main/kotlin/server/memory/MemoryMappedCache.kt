// Memory-mapped cache for efficient file I/O.
// Provides write, read, resize, and finalize operations.
// Matches Python MmapCache functionality.

package server.memory

import server.Logger
import java.io.RandomAccessFile
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.Files
import java.nio.file.Paths
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

const val DEFAULT_PAGE_SIZE = 64L * 1024 * 1024 // 64MB
const val MAX_CACHE_SIZE = 2L * 1024 * 1024 * 1024 // 2GB

/**
 * Memory-mapped cache implementation using Java's MappedByteBuffer.
 * Thread-safe with ReadWriteLock for concurrent access.
 */
class MemoryMappedCache(private val path: String) {
    private var file: RandomAccessFile? = null
    private var channel: FileChannel? = null
    private var mappedBuffer: MappedByteBuffer? = null
    private var size: Long = 0
    private var isOpen: Boolean = false
    private val rwLock = ReentrantReadWriteLock()

    /**
     * Create a new memory-mapped file.
     */
    fun create(initialSize: Long = 0): Boolean = rwLock.write {
        return try {
            // Remove existing file
            val filePath = Paths.get(path)
            if (Files.exists(filePath)) {
                Files.delete(filePath)
            }

            // Create and open file
            file = RandomAccessFile(path, "rw")
            channel = file!!.channel

            if (initialSize > 0) {
                // Set file size
                file!!.setLength(initialSize)
                size = initialSize

                // Map file into memory
                mapFile()
            } else {
                size = 0
            }

            isOpen = true
            Logger.debug("Created mmap file: $path with size: $initialSize")
            true
        } catch (e: Exception) {
            Logger.error("Error creating file $path: ${e.message}")
            close()
            false
        }
    }

    /**
     * Open an existing memory-mapped file.
     */
    fun open(): Boolean = rwLock.write {
        try {
            val filePath = Paths.get(path)
            if (!Files.exists(filePath)) {
                Logger.error("File does not exist: $path")
                return@write false
            }

            file = RandomAccessFile(path, "rw")
            channel = file!!.channel
            size = java.io.File(path).length()

            if (size > 0) {
                mapFile()
            }

            isOpen = true
            Logger.debug("Opened mmap file: $path with size: $size")
            true
        } catch (e: Exception) {
            Logger.error("Error opening file $path: ${e.message}")
            closeInternal()
            false
        }
    }

    /**
     * Close memory-mapped file.
     */
    fun close() = rwLock.write {
        closeInternal()
    }

    /**
     * Internal close without lock (called from within locked methods).
     */
    private fun closeInternal() {
        if (isOpen) {
            try {
                unmapFile()
            } catch (e: Exception) {
                Logger.error("Error closing file $path: ${e.message}")
            } finally {
                isOpen = false
            }
        }
    }

    /**
     * Write data to memory-mapped file.
     */
    fun write(offset: Long, data: ByteArray): Int = rwLock.write {
        try {
            // If file is not open, create it
            if (!isOpen) {
                val initialSize = offset + data.size
                if (!createInternal(initialSize)) {
                    return@write 0
                }
            }

            val requiredSize = offset + data.size
            
            // If file needs to grow or has no mapped buffer, resize it
            if (requiredSize > size || mappedBuffer == null) {
                val newSize = maxOf(requiredSize, size)
                if (!resizeInternal(newSize)) {
                    Logger.error("Failed to resize file for write operation")
                    return@write 0
                }
            }

            // Write to memory-mapped buffer
            mappedBuffer!!.position(offset.toInt())
            mappedBuffer!!.put(data)
            data.size
        } catch (e: Exception) {
            Logger.error("Error writing to file $path: ${e.message}")
            0
        }
    }

    /**
     * Read data from memory-mapped file.
     */
    fun read(offset: Long, length: Int): ByteArray = rwLock.write {
        try {
            if (!isOpen || mappedBuffer == null) {
                if (!openInternal()) {
                    Logger.error("Failed to open file for reading: $path")
                    return@write byteArrayOf()
                }
            }

            if (offset >= size) {
                return@write byteArrayOf()
            }

            // Read from memory-mapped buffer
            val actualLength = length.coerceAtMost((size - offset).toInt())
            val data = ByteArray(actualLength)

            mappedBuffer!!.position(offset.toInt())
            mappedBuffer!!.get(data)

            Logger.debug("Read $actualLength bytes from $path at offset $offset")
            data
        } catch (e: Exception) {
            Logger.error("Error reading from file $path: ${e.message}")
            byteArrayOf()
        }
    }

    /**
     * Get the size of the file.
     */
    fun getSize(): Long = rwLock.read { size }

    /**
     * Check if the file is open.
     */
    fun getIsOpen(): Boolean = rwLock.read { isOpen }

    /**
     * Resize the file to a new size (internal, no lock).
     */
    private fun resizeInternal(newSize: Long): Boolean {
        return try {
            if (!isOpen) {
                Logger.error("File not open for resize: $path")
                return false
            }

            if (newSize == size) {
                return true
            }

            // Unmap current buffer (but don't close file/channel)
            mappedBuffer = null

            // Resize file
            if (newSize < size) {
                Logger.warning("Truncating file $path to $newSize")
            }

            file!!.setLength(newSize)
            size = newSize

            // Remap file
            if (size > 0) {
                mapFile()
            }

            Logger.debug("Resized and remapped file $path to $newSize bytes")
            true
        } catch (e: Exception) {
            Logger.error("Error resizing file $path: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    /**
     * Finalize the file to its final size.
     */
    fun finalize(finalSize: Long): Boolean = rwLock.write {
        try {
            if (!isOpen) {
                Logger.warning("File not open for finalization: $path")
                return@write false
            }

            if (!resizeInternal(finalSize)) {
                Logger.error("Failed to resize file during finalization: $path")
                return@write false
            }

            // Force mapped buffer to write to disk
            mappedBuffer?.force()

            Logger.debug("Finalized file: $path with size: $finalSize")
            true
        } catch (e: Exception) {
            Logger.error("Error finalizing file $path: ${e.message}")
            false
        }
    }

    /**
     * Create internal without lock.
     */
    private fun createInternal(initialSize: Long): Boolean {
        return try {
            // Remove existing file
            val filePath = Paths.get(path)
            if (Files.exists(filePath)) {
                Files.delete(filePath)
            }

            // Create and open file
            file = RandomAccessFile(path, "rw")
            channel = file!!.channel

            if (initialSize > 0) {
                // Set file size
                file!!.setLength(initialSize)
                size = initialSize

                // Map file into memory
                mapFile()
            } else {
                size = 0
            }

            isOpen = true
            Logger.debug("Created mmap file: $path with size: $initialSize")
            true
        } catch (e: Exception) {
            Logger.error("Error creating file $path: ${e.message}")
            closeInternal()
            false
        }
    }

    /**
     * Open internal without lock.
     */
    private fun openInternal(): Boolean {
        return try {
            val filePath = Paths.get(path)
            if (!Files.exists(filePath)) {
                Logger.error("File does not exist: $path")
                return false
            }

            file = RandomAccessFile(path, "rw")
            channel = file!!.channel
            size = java.io.File(path).length()

            if (size > 0) {
                mapFile()
            }

            isOpen = true
            Logger.debug("Opened mmap file: $path with size: $size")
            true
        } catch (e: Exception) {
            Logger.error("Error opening file $path: ${e.message}")
            closeInternal()
            false
        }
    }

    /**
     * Map the file into memory using MappedByteBuffer.
     */
    private fun mapFile() {
        if (channel != null && size > 0) {
            // Map entire file into memory (READ_WRITE mode for both reading and writing)
            mappedBuffer = channel!!.map(
                FileChannel.MapMode.READ_WRITE,
                0,
                size
            )
            Logger.debug("Successfully mapped file: $path ($size bytes)")
        }
    }

    /**
     * Unmap the file from memory and close resources.
     */
    private fun unmapFile() {
        mappedBuffer = null

        if (channel != null) {
            try {
                channel!!.close()
            } catch (e: Exception) {
                Logger.error("Error closing channel: ${e.message}")
            }
            channel = null
        }

        if (file != null) {
            try {
                file!!.close()
            } catch (e: Exception) {
                Logger.error("Error closing file: ${e.message}")
            }
            file = null
        }
    }
}
