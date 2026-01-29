package org.feuyeux.mmap.audio.server.memory;

import java.time.Instant;

/**
 * Stream context for managing active audio streams.
 * Contains stream metadata and cache file handle.
 * Matches C++ StreamContext structure.
 */
public class StreamContext {
    public enum StreamStatus {
        UPLOADING,
        READY,
        ERROR
    }

    private String streamId;
    private String cachePath;
    private MemoryMappedCache mmapFile;
    private long currentOffset;
    private long totalSize;
    private Instant createdAt;
    private Instant lastAccessedAt;
    private StreamStatus status;

    public StreamContext() {
        this.currentOffset = 0;
        this.totalSize = 0;
        this.createdAt = Instant.now();
        this.lastAccessedAt = Instant.now();
        this.status = StreamStatus.UPLOADING;
    }

    public StreamContext(String streamId) {
        this();
        this.streamId = streamId;
    }

    // Getters and setters
    public String getStreamId() {
        return streamId;
    }

    public void setStreamId(String streamId) {
        this.streamId = streamId;
    }

    public String getCachePath() {
        return cachePath;
    }

    public void setCachePath(String cachePath) {
        this.cachePath = cachePath;
    }

    public MemoryMappedCache getMmapFile() {
        return mmapFile;
    }

    public void setMmapFile(MemoryMappedCache mmapFile) {
        this.mmapFile = mmapFile;
    }

    public long getCurrentOffset() {
        return currentOffset;
    }

    public void setCurrentOffset(long currentOffset) {
        this.currentOffset = currentOffset;
    }

    public long getTotalSize() {
        return totalSize;
    }

    public void setTotalSize(long totalSize) {
        this.totalSize = totalSize;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getLastAccessedAt() {
        return lastAccessedAt;
    }

    public void setLastAccessedAt(Instant lastAccessedAt) {
        this.lastAccessedAt = lastAccessedAt;
    }

    public StreamStatus getStatus() {
        return status;
    }

    public void setStatus(StreamStatus status) {
        this.status = status;
    }
}
