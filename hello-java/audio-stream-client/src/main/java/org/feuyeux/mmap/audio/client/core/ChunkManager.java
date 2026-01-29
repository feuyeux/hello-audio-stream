package org.feuyeux.mmap.audio.client.core;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;

/**
 * Chunk manager for splitting and assembling audio data.
 * Handles chunking logic for upload and download operations.
 * Matches the C++ ChunkManager interface.
 */
public class ChunkManager {
    private static final Logger logger = LoggerFactory.getLogger(ChunkManager.class);
    private static final int CHUNK_SIZE = 65536; // 64KB

    private final Map<Long, byte[]> chunks;

    public ChunkManager() {
        this.chunks = new TreeMap<>(); // TreeMap maintains order by offset
    }

    // Upload chunking methods

    /**
     * Split data into chunks.
     *
     * @param data data to split
     * @return list of chunks
     */
    public List<byte[]> splitIntoChunks(byte[] data) {
        List<byte[]> chunkList = new ArrayList<>();
        
        int offset = 0;
        while (offset < data.length) {
            int chunkLength = Math.min(CHUNK_SIZE, data.length - offset);
            byte[] chunk = new byte[chunkLength];
            System.arraycopy(data, offset, chunk, 0, chunkLength);
            chunkList.add(chunk);
            offset += chunkLength;
        }
        
        logger.debug("Split {} bytes into {} chunks", data.length, chunkList.size());
        return chunkList;
    }

    /**
     * Calculate the number of chunks needed for a given size.
     *
     * @param totalSize total size in bytes
     * @return number of chunks
     */
    public int calculateChunkCount(long totalSize) {
        return (int) ((totalSize + CHUNK_SIZE - 1) / CHUNK_SIZE);
    }

    // Download assembly methods

    /**
     * Add a chunk at a specific offset.
     *
     * @param offset byte offset where this chunk starts
     * @param chunk chunk data
     */
    public void addChunk(long offset, byte[] chunk) {
        chunks.put(offset, chunk);
        logger.debug("Added chunk at offset {} ({} bytes)", offset, chunk.length);
    }

    /**
     * Assemble all chunks into a single byte array.
     *
     * @return assembled data
     */
    public byte[] assembleChunks() {
        if (chunks.isEmpty()) {
            logger.warn("No chunks to assemble");
            return new byte[0];
        }

        // Calculate total size
        long totalSize = 0;
        for (byte[] chunk : chunks.values()) {
            totalSize += chunk.length;
        }

        // Assemble chunks in order
        byte[] result = new byte[(int) totalSize];
        int position = 0;
        
        for (Map.Entry<Long, byte[]> entry : chunks.entrySet()) {
            byte[] chunk = entry.getValue();
            System.arraycopy(chunk, 0, result, position, chunk.length);
            position += chunk.length;
        }

        logger.debug("Assembled {} chunks into {} bytes", chunks.size(), totalSize);
        return result;
    }

    /**
     * Reset the chunk manager, clearing all stored chunks.
     */
    public void reset() {
        chunks.clear();
        logger.debug("Reset chunk manager");
    }

    // Utility methods

    /**
     * Get the chunk size.
     *
     * @return chunk size in bytes (64KB)
     */
    public int getChunkSize() {
        return CHUNK_SIZE;
    }

    /**
     * Get the number of chunks currently stored.
     *
     * @return number of chunks
     */
    public int getChunkCount() {
        return chunks.size();
    }

    /**
     * Check if a chunk exists at a specific offset.
     *
     * @param offset byte offset
     * @return true if chunk exists
     */
    public boolean hasChunk(long offset) {
        return chunks.containsKey(offset);
    }
}
