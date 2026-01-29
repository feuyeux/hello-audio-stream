package org.feuyeux.mmap.audio.server.memory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * Memory-mapped file cache for efficient data storage.
 * Provides zero-copy read/write access to cached files.
 * Follows the unified mmap implementation specification v2.0.0.
 * 
 * Key Features:
 * - Large file support (>2GB) using segmented mapping
 * - Batch operations for improved I/O efficiency
 * - Thread-safe operations with read-write locks
 * - Memory management with flush/prefetch/evict
 * - Enhanced error handling and validation
 * 
 * @author Memory Map Working Group
 * @version 2.0.0
 */
public class MemoryMappedCache implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(MemoryMappedCache.class);

    // Configuration constants
    private static final long SEGMENT_SIZE = 1L * 1024 * 1024 * 1024;  // 1GB per segment
    private static final long MAX_CACHE_SIZE = 8L * 1024 * 1024 * 1024;  // 8GB total
    private static final int BATCH_OPERATION_LIMIT = 1000;

    // Instance fields
    private final String path;
    private final ReadWriteLock rwLock;
    private final Map<Long, MappedByteBuffer> segments;
    
    private RandomAccessFile file;
    private FileChannel fileChannel;
    private long fileSize;
    private boolean isOpen;

    /**
     * Create a new MemoryMappedCache instance.
     *
     * @param path file path for the memory-mapped file
     */
    public MemoryMappedCache(String path) {
        this.path = path;
        this.fileSize = 0;
        this.isOpen = false;
        this.rwLock = new ReentrantReadWriteLock();
        this.segments = new ConcurrentHashMap<>();
    }

    /**
     * Create a new memory-mapped file.
     *
     * @param initialSize initial size of the file (0 for no pre-allocation)
     * @return true if successful
     * @throws IOException if file operations fail
     */
    public boolean create(long initialSize) throws IOException {
        rwLock.writeLock().lock();
        try {
            validateSize(initialSize);
            logger.debug("Creating mmap file: {} with initial size: {}", path, initialSize);

            Path filePath = Paths.get(path);
            Files.deleteIfExists(filePath);

            file = new RandomAccessFile(filePath.toFile(), "rw");
            fileChannel = file.getChannel();

            if (initialSize > 0) {
                file.setLength(initialSize);
                fileSize = initialSize;
            } else {
                fileSize = 0;
            }

            isOpen = true;
            logger.debug("Created mmap file: {} with size: {}", path, fileSize);
            return true;
            
        } catch (IOException e) {
            logError("create", e);
            throw e;
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Open an existing memory-mapped file.
     *
     * @return true if successful
     * @throws IOException if file operations fail
     */
    public boolean open() throws IOException {
        rwLock.writeLock().lock();
        try {
            logger.debug("Opening mmap file: {}", path);

            Path filePath = Paths.get(path);
            if (!Files.exists(filePath)) {
                logger.error("File does not exist: {}", path);
                return false;
            }

            file = new RandomAccessFile(filePath.toFile(), "rw");
            fileChannel = file.getChannel();
            fileSize = file.length();

            isOpen = true;
            logger.debug("Opened mmap file: {} with size: {}", path, fileSize);
            return true;
            
        } catch (IOException e) {
            logError("open", e);
            throw e;
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Close the memory-mapped file and release resources.
     *
     * @throws IOException if close operation fails
     */
    @Override
    public void close() throws IOException {
        rwLock.writeLock().lock();
        try {
            if (isOpen) {
                unmapAllSegments();
                
                if (fileChannel != null) {
                    fileChannel.close();
                    fileChannel = null;
                }
                
                if (file != null) {
                    file.close();
                    file = null;
                }
                
                isOpen = false;
                logger.debug("Closed mmap file: {}", path);
            }
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Write data to the memory-mapped file at the specified offset.
     *
     * @param offset starting position
     * @param data   data to write
     * @return number of bytes written
     * @throws IOException if write operation fails
     */
    public int write(long offset, ByteBuffer data) throws IOException {
        rwLock.writeLock().lock();
        try {
            int dataSize = data.remaining();
            
            // Auto-create if not open
            if (!isOpen) {
                long initialSize = offset + dataSize;
                if (!create(initialSize)) {
                    return 0;
                }
            }

            validateOffset(offset, dataSize);

            // Resize if needed
            long requiredSize = offset + dataSize;
            if (requiredSize > fileSize) {
                if (!resize(requiredSize)) {
                    logger.error("Failed to resize file for write operation");
                    return 0;
                }
            }

            // Write to appropriate segment(s)
            int bytesWritten = 0;
            long currentOffset = offset;
            
            while (data.hasRemaining()) {
                MappedByteBuffer segment = getOrCreateSegment(currentOffset);
                int segmentOffset = (int) (currentOffset % SEGMENT_SIZE);
                int bytesToWrite = Math.min(data.remaining(), (int) SEGMENT_SIZE - segmentOffset);
                
                segment.position(segmentOffset);
                ByteBuffer slice = data.slice();
                slice.limit(bytesToWrite);
                segment.put(slice);
                
                data.position(data.position() + bytesToWrite);
                currentOffset += bytesToWrite;
                bytesWritten += bytesToWrite;
            }

            logger.debug("Wrote {} bytes to {} at offset {}", bytesWritten, path, offset);
            return bytesWritten;
            
        } catch (IOException e) {
            logError("write", e);
            throw e;
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Read data from the memory-mapped file at the specified offset.
     *
     * @param offset starting position
     * @param length number of bytes to read
     * @return ByteBuffer containing the data, or null if offset is beyond file size
     * @throws IOException if read operation fails
     */
    public ByteBuffer read(long offset, int length) throws IOException {
        rwLock.readLock().lock();
        try {
            // Auto-open if not open
            if (!isOpen) {
                rwLock.readLock().unlock();
                rwLock.writeLock().lock();
                try {
                    if (!isOpen) {
                        logger.debug("File not open, attempting to open for reading: {}", path);
                        if (!open()) {
                            logger.error("Failed to open file for reading: {}", path);
                            return null;
                        }
                    }
                    rwLock.readLock().lock();
                } finally {
                    rwLock.writeLock().unlock();
                }
            }

            if (offset >= fileSize) {
                logger.debug("Read offset {} at or beyond file size {} - end of file", offset, fileSize);
                return null;
            }

            int actualLength = (int) Math.min(length, fileSize - offset);
            ByteBuffer result = ByteBuffer.allocate(actualLength);

            // Read from appropriate segment(s)
            long currentOffset = offset;
            int bytesRead = 0;
            
            while (bytesRead < actualLength) {
                MappedByteBuffer segment = getOrCreateSegment(currentOffset);
                int segmentOffset = (int) (currentOffset % SEGMENT_SIZE);
                int bytesToRead = Math.min(actualLength - bytesRead, (int) SEGMENT_SIZE - segmentOffset);
                
                segment.position(segmentOffset);
                segment.limit(segmentOffset + bytesToRead);
                result.put(segment);
                segment.limit(segment.capacity());
                
                currentOffset += bytesToRead;
                bytesRead += bytesToRead;
            }

            result.flip();
            logger.debug("Read {} bytes from {} at offset {}", actualLength, path, offset);
            return result;
            
        } catch (IOException e) {
            logError("read", e);
            throw e;
        } finally {
            rwLock.readLock().unlock();
        }
    }

    /**
     * Batch write operations for improved I/O efficiency.
     *
     * @param operations list of write operations
     * @return list of bytes written for each operation
     * @throws IOException if any write operation fails
     */
    public List<Integer> writeBatch(List<WriteOperation> operations) throws IOException {
        if (operations.size() > BATCH_OPERATION_LIMIT) {
            throw new IOException("Batch operation limit exceeded: " + operations.size());
        }

        List<Integer> results = new ArrayList<>(operations.size());
        for (WriteOperation op : operations) {
            int written = write(op.offset, op.data);
            results.add(written);
        }
        return results;
    }

    /**
     * Batch read operations for improved I/O efficiency.
     *
     * @param operations list of read operations
     * @return list of ByteBuffers for each operation
     * @throws IOException if any read operation fails
     */
    public List<ByteBuffer> readBatch(List<ReadOperation> operations) throws IOException {
        if (operations.size() > BATCH_OPERATION_LIMIT) {
            throw new IOException("Batch operation limit exceeded: " + operations.size());
        }

        List<ByteBuffer> results = new ArrayList<>(operations.size());
        for (ReadOperation op : operations) {
            ByteBuffer data = read(op.offset, op.length);
            results.add(data);
        }
        return results;
    }

    /**
     * Force synchronization of data to disk.
     *
     * @return true if successful
     * @throws IOException if flush operation fails
     */
    public boolean flush() throws IOException {
        rwLock.readLock().lock();
        try {
            if (!isOpen) {
                logger.warn("File not open for flush: {}", path);
                return false;
            }

            for (MappedByteBuffer segment : segments.values()) {
                segment.force();
            }

            logger.debug("Flushed file: {}", path);
            return true;
            
        } finally {
            rwLock.readLock().unlock();
        }
    }

    /**
     * Prefetch data into memory for performance optimization.
     *
     * @param offset starting position
     * @param length number of bytes to prefetch
     * @return true if successful
     * @throws IOException if prefetch operation fails
     */
    public boolean prefetch(long offset, int length) throws IOException {
        rwLock.readLock().lock();
        try {
            if (!isOpen) {
                logger.warn("File not open for prefetch: {}", path);
                return false;
            }

            validateOffset(offset, length);

            // Load segments into memory
            long currentOffset = offset;
            int remaining = length;
            
            while (remaining > 0) {
                MappedByteBuffer segment = getOrCreateSegment(currentOffset);
                int segmentOffset = (int) (currentOffset % SEGMENT_SIZE);
                int bytesToLoad = Math.min(remaining, (int) SEGMENT_SIZE - segmentOffset);
                
                segment.load();  // Prefetch into memory
                
                currentOffset += bytesToLoad;
                remaining -= bytesToLoad;
            }

            logger.debug("Prefetched {} bytes from {} at offset {}", length, path, offset);
            return true;
            
        } finally {
            rwLock.readLock().unlock();
        }
    }

    /**
     * Evict data from memory to free resources.
     *
     * @param offset starting position
     * @param length number of bytes to evict
     * @return true if successful
     * @throws IOException if evict operation fails
     */
    public boolean evict(long offset, int length) throws IOException {
        rwLock.writeLock().lock();
        try {
            if (!isOpen) {
                logger.warn("File not open for evict: {}", path);
                return false;
            }

            validateOffset(offset, length);

            // Unmap segments in range
            long startSegment = offset / SEGMENT_SIZE;
            long endSegment = (offset + length - 1) / SEGMENT_SIZE;
            
            for (long segmentIndex = startSegment; segmentIndex <= endSegment; segmentIndex++) {
                segments.remove(segmentIndex);
            }

            logger.debug("Evicted {} bytes from {} at offset {}", length, path, offset);
            return true;
            
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Get the current file size.
     *
     * @return file size in bytes
     */
    public long getSize() {
        return fileSize;
    }

    /**
     * Get the file path.
     *
     * @return file path string
     */
    public String getPath() {
        return path;
    }

    /**
     * Check if the memory-mapped file is open.
     *
     * @return true if open
     */
    public boolean isOpen() {
        return isOpen;
    }

    /**
     * Resize the memory-mapped file to a new size.
     *
     * @param newSize new file size
     * @return true if successful
     * @throws IOException if resize operation fails
     */
    public boolean resize(long newSize) throws IOException {
        rwLock.writeLock().lock();
        try {
            if (!isOpen) {
                logger.error("File not open for resize: {}", path);
                return false;
            }

            validateSize(newSize);

            if (newSize == fileSize) {
                return true;
            }

            // Unmap all segments before resizing
            unmapAllSegments();
            
            file.setLength(newSize);
            fileSize = newSize;

            logger.debug("Resized file {} to {} bytes", path, newSize);
            return true;
            
        } catch (IOException e) {
            logError("resize", e);
            throw e;
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    /**
     * Finalize the memory-mapped file by truncating to the specified size.
     *
     * @param finalSize final file size
     * @return true if successful
     * @throws IOException if finalization fails
     */
    public boolean finalize(long finalSize) throws IOException {
        rwLock.writeLock().lock();
        try {
            if (!isOpen) {
                logger.warn("File not open for finalization: {}", path);
                return false;
            }

            if (!resize(finalSize)) {
                logger.error("Failed to resize file during finalization: {}", path);
                return false;
            }

            flush();

            logger.debug("Finalized file: {} with size: {}", path, finalSize);
            return true;
            
        } finally {
            rwLock.writeLock().unlock();
        }
    }

    // Private helper methods

    private MappedByteBuffer getOrCreateSegment(long offset) throws IOException {
        long segmentIndex = offset / SEGMENT_SIZE;
        
        return segments.computeIfAbsent(segmentIndex, index -> {
            try {
                long segmentOffset = index * SEGMENT_SIZE;
                long segmentSize = Math.min(SEGMENT_SIZE, fileSize - segmentOffset);
                
                if (segmentSize <= 0) {
                    throw new IOException("Invalid segment size: " + segmentSize);
                }
                
                return fileChannel.map(FileChannel.MapMode.READ_WRITE, segmentOffset, segmentSize);
            } catch (IOException e) {
                logger.error("Failed to map segment {} for file: {}", index, path, e);
                throw new RuntimeException("Failed to map segment", e);
            }
        });
    }

    private void unmapAllSegments() {
        for (MappedByteBuffer segment : segments.values()) {
            segment.force();
        }
        segments.clear();
    }

    private void validateOffset(long offset, long length) throws IOException {
        if (offset < 0) {
            throw new IOException("Invalid offset: " + offset);
        }
        if (length < 0) {
            throw new IOException("Invalid length: " + length);
        }
        if (offset + length > MAX_CACHE_SIZE) {
            throw new IOException("Operation exceeds maximum cache size");
        }
    }

    private void validateSize(long size) throws IOException {
        if (size < 0) {
            throw new IOException("Invalid size: " + size);
        }
        if (size > MAX_CACHE_SIZE) {
            throw new IOException("Size exceeds maximum cache size: " + size);
        }
    }

    private void logError(String operation, Exception error) {
        logger.error("Error in {} operation for file {}: {}", operation, path, error.getMessage(), error);
    }

    /**
     * Write operation for batch processing.
     */
    public static class WriteOperation {
        public final long offset;
        public final ByteBuffer data;

        public WriteOperation(long offset, ByteBuffer data) {
            this.offset = offset;
            this.data = data;
        }
    }

    /**
     * Read operation for batch processing.
     */
    public static class ReadOperation {
        public final long offset;
        public final int length;

        public ReadOperation(long offset, int length) {
            this.offset = offset;
            this.length = length;
        }
    }
}
