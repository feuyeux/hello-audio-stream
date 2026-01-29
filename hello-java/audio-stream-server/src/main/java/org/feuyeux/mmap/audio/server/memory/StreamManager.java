package org.feuyeux.mmap.audio.server.memory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Stream manager for managing active audio streams.
 * Thread-safe registry of stream contexts.
 * Matches C++ StreamManager functionality and lifecycle.
 */
public class StreamManager {
    private static final Logger logger = LoggerFactory.getLogger(StreamManager.class);

    private final String cacheDirectory;
    private final Map<String, StreamContext> streams;
    private final ReentrantLock mutex;

    public StreamManager() {
        this.cacheDirectory = System.getProperty("cache.dir", "cache");
        this.streams = new ConcurrentHashMap<>();
        this.mutex = new ReentrantLock();

        // Create cache directory if it doesn't exist
        try {
            Path cachePath = Paths.get(cacheDirectory);
            if (!Files.exists(cachePath)) {
                Files.createDirectories(cachePath);
                logger.info("StreamManager initialized with cache directory: {}", cacheDirectory);
            }
        } catch (IOException e) {
            logger.error("Failed to create cache directory: {}", cacheDirectory, e);
            throw new RuntimeException("Cannot initialize cache directory", e);
        }
    }

    /**
     * Create a new stream.
     *
     * @param streamId unique identifier for the stream
     * @return true if successful, false if stream already exists
     */
    public boolean createStream(String streamId) {
        mutex.lock();
        try {
            // Check if stream already exists
            if (streams.containsKey(streamId)) {
                logger.warn("Stream already exists: {}", streamId);
                return false;
            }

            // Create new stream context
            StreamContext context = new StreamContext(streamId);
            context.setCachePath(getCachePath(streamId));
            context.setCurrentOffset(0);
            context.setTotalSize(0);
            context.setStatus(StreamContext.StreamStatus.UPLOADING);
            context.setCreatedAt(Instant.now());
            context.setLastAccessedAt(Instant.now());

            // Create memory-mapped cache file
            MemoryMappedCache mmapFile = new MemoryMappedCache(context.getCachePath());
            context.setMmapFile(mmapFile);

            // Add to registry
            streams.put(streamId, context);

            logger.info("Created stream: {} at path: {}", streamId, context.getCachePath());
            return true;

        } catch (Exception e) {
            logger.error("Failed to create stream {}: {}", streamId, e.getMessage(), e);
            return false;
        } finally {
            mutex.unlock();
        }
    }

    /**
     * Get a stream context.
     *
     * @param streamId unique identifier for the stream
     * @return stream context or null if not found
     */
    public StreamContext getStream(String streamId) {
        mutex.lock();
        try {
            StreamContext context = streams.get(streamId);
            if (context != null) {
                // Update last accessed time
                context.setLastAccessedAt(Instant.now());
            }
            return context;
        } finally {
            mutex.unlock();
        }
    }

    /**
     * Delete a stream.
     *
     * @param streamId unique identifier for the stream
     * @return true if successful
     */
    public boolean deleteStream(String streamId) {
        mutex.lock();
        try {
            StreamContext context = streams.get(streamId);
            if (context == null) {
                logger.warn("Stream not found for deletion: {}", streamId);
                return false;
            }

            // Close memory-mapped file
            if (context.getMmapFile() != null) {
                context.getMmapFile().close();
            }

            // Remove cache file
            Files.deleteIfExists(Paths.get(context.getCachePath()));

            // Remove from registry
            streams.remove(streamId);

            logger.info("Deleted stream: {}", streamId);
            return true;

        } catch (IOException e) {
            logger.error("Failed to delete stream {}: {}", streamId, e.getMessage(), e);
            return false;
        } finally {
            mutex.unlock();
        }
    }

    /**
     * List all active streams.
     *
     * @return list of stream IDs
     */
    public List<String> listActiveStreams() {
        mutex.lock();
        try {
            return new ArrayList<>(streams.keySet());
        } finally {
            mutex.unlock();
        }
    }

    /**
     * Write a chunk of data to a stream.
     *
     * @param streamId unique identifier for the stream
     * @param data     data to write
     * @return true if successful
     */
    public boolean writeChunk(String streamId, byte[] data) {
        StreamContext stream = getStream(streamId);
        if (stream == null) {
            logger.error("Stream not found for write: {}", streamId);
            return false;
        }

        if (stream.getStatus() != StreamContext.StreamStatus.UPLOADING) {
            logger.error("Stream {} is not in uploading state", streamId);
            return false;
        }

        try {
            // Write data to memory-mapped file
            ByteBuffer buffer = ByteBuffer.wrap(data);
            int written = stream.getMmapFile().write(stream.getCurrentOffset(), buffer);

            if (written > 0) {
                stream.setCurrentOffset(stream.getCurrentOffset() + written);
                stream.setTotalSize(stream.getTotalSize() + written);
                stream.setLastAccessedAt(Instant.now());

                logger.debug("Wrote {} bytes to stream {} at offset {}",
                        written, streamId, stream.getCurrentOffset() - written);
                return true;
            } else {
                logger.error("Failed to write data to stream {}", streamId);
                return false;
            }

        } catch (IOException e) {
            logger.error("Error writing to stream {}: {}", streamId, e.getMessage(), e);
            return false;
        }
    }

    /**
     * Read a chunk of data from a stream.
     *
     * @param streamId unique identifier for the stream
     * @param offset   starting position
     * @param length   number of bytes to read
     * @return data read, or empty array if error
     */
    public byte[] readChunk(String streamId, long offset, int length) {
        StreamContext stream = getStream(streamId);
        if (stream == null) {
            logger.error("Stream not found for read: {}", streamId);
            return new byte[0];
        }

        try {
            // Read data from memory-mapped file
            ByteBuffer buffer = stream.getMmapFile().read(offset, length);
            stream.setLastAccessedAt(Instant.now());

            if (buffer != null) {
                byte[] data = new byte[buffer.remaining()];
                buffer.get(data);
                logger.debug("Read {} bytes from stream {} at offset {}", data.length, streamId, offset);
                return data;
            } else {
                return new byte[0];
            }

        } catch (IOException e) {
            logger.error("Error reading from stream {}: {}", streamId, e.getMessage(), e);
            return new byte[0];
        }
    }

    /**
     * Finalize a stream (flush and mark as ready).
     *
     * @param streamId unique identifier for the stream
     * @return true if successful
     */
    public boolean finalizeStream(String streamId) {
        StreamContext stream = getStream(streamId);
        if (stream == null) {
            logger.error("Stream not found for finalization: {}", streamId);
            return false;
        }

        if (stream.getStatus() != StreamContext.StreamStatus.UPLOADING) {
            logger.warn("Stream {} is not in uploading state for finalization", streamId);
            return false;
        }

        try {
            // Finalize memory-mapped file
            if (stream.getMmapFile().finalize(stream.getTotalSize())) {
                stream.setStatus(StreamContext.StreamStatus.READY);
                stream.setLastAccessedAt(Instant.now());

                logger.info("Finalized stream: {} with {} bytes", streamId, stream.getTotalSize());
                return true;
            } else {
                logger.error("Failed to finalize memory-mapped file for stream {}", streamId);
                return false;
            }

        } catch (IOException e) {
            logger.error("Error finalizing stream {}: {}", streamId, e.getMessage(), e);
            return false;
        }
    }

    /**
     * Clean up old streams (older than 24 hours).
     */
    public void cleanupOldStreams() {
        mutex.lock();
        try {
            Instant now = Instant.now();
            Duration cutoff = Duration.ofHours(24);

            List<String> toRemove = new ArrayList<>();
            for (Map.Entry<String, StreamContext> entry : streams.entrySet()) {
                Duration age = Duration.between(entry.getValue().getLastAccessedAt(), now);
                if (age.compareTo(cutoff) > 0) {
                    toRemove.add(entry.getKey());
                }
            }

            for (String streamId : toRemove) {
                logger.info("Cleaning up old stream: {}", streamId);
                deleteStream(streamId);
            }

        } finally {
            mutex.unlock();
        }
    }

    /**
     * Get cache file path for a stream.
     *
     * @param streamId unique identifier for the stream
     * @return cache file path
     */
    private String getCachePath(String streamId) {
        return cacheDirectory + "/" + streamId + ".cache";
    }
}
