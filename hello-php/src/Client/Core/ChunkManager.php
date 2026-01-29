<?php

namespace AudioStreamClient\Core;

/**
 * Chunk manager for handling file chunking operations.
 * Provides utilities for splitting and reassembling data.
 */
class ChunkManager
{
    private const DEFAULT_CHUNK_SIZE = 8192; // 8KB

    /**
     * Split data into chunks.
     *
     * @param string $data Data to split
     * @param int $chunkSize Size of each chunk
     * @return array Array of chunks
     */
    public static function splitIntoChunks(string $data, int $chunkSize = self::DEFAULT_CHUNK_SIZE): array
    {
        $chunks = [];
        $offset = 0;
        $dataSize = strlen($data);

        while ($offset < $dataSize) {
            $size = min($chunkSize, $dataSize - $offset);
            $chunks[] = substr($data, $offset, $size);
            $offset += $size;
        }

        return $chunks;
    }

    /**
     * Get the number of chunks for a given data size.
     *
     * @param int $dataSize Total data size
     * @param int $chunkSize Size of each chunk
     * @return int Number of chunks
     */
    public static function getChunkCount(int $dataSize, int $chunkSize = self::DEFAULT_CHUNK_SIZE): int
    {
        return (int)ceil($dataSize / $chunkSize);
    }

    /**
     * Get the default chunk size.
     *
     * @return int Default chunk size
     */
    public static function getDefaultChunkSize(): int
    {
        return self::DEFAULT_CHUNK_SIZE;
    }
}
