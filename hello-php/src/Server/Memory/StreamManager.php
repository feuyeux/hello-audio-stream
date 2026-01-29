<?php

/**
 * Stream manager for managing active audio streams.
 * Thread-safe registry of stream contexts.
 * Matches Python StreamManager and Java StreamManager functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

use AudioStreamClient\Logger;

/**
 * Stream manager for managing multiple concurrent streams.
 */
class StreamManager
{
    private static ?self $instance = null;
    private string $cacheDirectory;
    private array $streams;

    /**
     * Get the singleton instance of StreamManager.
     *
     * @param string $cacheDirectory Directory for cache files (default 'cache')
     * @return self The singleton instance
     */
    public static function getInstance(
        string $cacheDirectory = 'cache'
    ): self {
        if (self::$instance === null) {
            self::$instance = new self($cacheDirectory);
        }
        return self::$instance;
    }

    /**
     * Private constructor for singleton pattern.
     *
     * @param string $cacheDirectory Directory for cache files
     */
    private function __construct(string $cacheDirectory)
    {
        $this->cacheDirectory = $cacheDirectory;
        $this->streams = [];

        // Create cache directory if it doesn't exist
        if (!is_dir($cacheDirectory)) {
            mkdir($cacheDirectory, 0755, true);
        }

        Logger::info("StreamManager initialized with cache directory: {$cacheDirectory}");
    }

    /**
     * Create a new stream.
     *
     * @param string $streamId Unique identifier for the stream
     * @return bool True if successful, False if stream already exists
     */
    public function createStream(string $streamId): bool
    {
        // Check if stream already exists
        if (isset($this->streams[$streamId])) {
            Logger::warning("Stream already exists: {$streamId}");
            return false;
        }

        try {
            // Create new stream context
            $cachePath = $this->getCachePath($streamId);
            $context = new StreamContext($streamId, $cachePath);
            $context->setStatus(StreamStatus::UPLOADING);
            $context->updateAccessTime();

            // Create memory-mapped cache file
            $mmapFile = new MemoryMappedCache($cachePath);
            if (!$mmapFile->create($cachePath, 0)) {
                throw new \Exception("Failed to create mmap file");
            }
            $context->setMmapFile($mmapFile);

            // Add to registry
            $this->streams[$streamId] = $context;

            Logger::info("Created stream: {$streamId} at path: {$cachePath}");
            return true;

        } catch (\Exception $e) {
            Logger::error("Failed to create stream {$streamId}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Get a stream context.
     *
     * @param string $streamId Unique identifier for the stream
     * @return StreamContext|null Stream context or null if not found
     */
    public function getStream(string $streamId): ?StreamContext
    {
        $context = $this->streams[$streamId] ?? null;
        if ($context !== null) {
            $context->updateAccessTime();
        }
        return $context;
    }

    /**
     * Delete a stream.
     *
     * @param string $streamId Unique identifier for the stream
     * @return bool True if successful
     */
    public function deleteStream(string $streamId): bool
    {
        $context = $this->streams[$streamId] ?? null;
        if ($context === null) {
            Logger::warning("Stream not found for deletion: {$streamId}");
            return false;
        }

        try {
            // Close memory-mapped file
            $mmapFile = $context->getMmapFile();
            if ($mmapFile !== null) {
                $mmapFile->close();
            }

            // Remove cache file
            if (file_exists($context->getCachePath())) {
                unlink($context->getCachePath());
            }

            // Remove from registry
            unset($this->streams[$streamId]);

            Logger::info("Deleted stream: {$streamId}");
            return true;

        } catch (\Exception $e) {
            Logger::error("Failed to delete stream {$streamId}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * List all active streams.
     *
     * @return array List of stream IDs
     */
    public function listActiveStreams(): array
    {
        return array_keys($this->streams);
    }

    /**
     * Write a chunk of data to a stream.
     *
     * @param string $streamId Unique identifier for the stream
     * @param string $data Data to write
     * @return bool True if successful
     */
    public function writeChunk(string $streamId, string $data): bool
    {
        $stream = $this->getStream($streamId);
        if ($stream === null) {
            Logger::error("Stream not found for write: {$streamId}");
            return false;
        }

        if ($stream->getStatus() !== StreamStatus::UPLOADING) {
            Logger::error("Stream {$streamId} is not in uploading state");
            return false;
        }

        try {
            // Write data to memory-mapped file
            $mmapFile = $stream->getMmapFile();
            $written = $mmapFile->write($stream->getCurrentOffset(), $data);

            if ($written > 0) {
                $stream->setCurrentOffset($stream->getCurrentOffset() + $written);
                $stream->setTotalSize($stream->getTotalSize() + $written);
                $stream->updateAccessTime();

                Logger::debug("Wrote {$written} bytes to stream {$streamId} at offset " . ($stream->getCurrentOffset() - $written));
                return true;
            } else {
                Logger::error("Failed to write data to stream {$streamId}");
                return false;
            }

        } catch (\Exception $e) {
            Logger::error("Error writing to stream {$streamId}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Read a chunk of data from a stream.
     *
     * @param string $streamId Unique identifier for the stream
     * @param int $offset Starting position
     * @param int $length Number of bytes to read
     * @return string Data read, or empty string if error
     */
    public function readChunk(string $streamId, int $offset, int $length): string
    {
        $stream = $this->getStream($streamId);
        if ($stream === null) {
            Logger::error("Stream not found for read: {$streamId}");
            return '';
        }

        try {
            // Read data from memory-mapped file
            $mmapFile = $stream->getMmapFile();
            $data = $mmapFile->read($offset, $length);
            $stream->updateAccessTime();

            Logger::debug("Read " . strlen($data) . " bytes from stream {$streamId} at offset {$offset}");
            return $data;

        } catch (\Exception $e) {
            Logger::error("Error reading from stream {$streamId}: " . $e->getMessage());
            return '';
        }
    }

    /**
     * Finalize a stream (flush and mark as ready).
     *
     * @param string $streamId Unique identifier for the stream
     * @return bool True if successful
     */
    public function finalizeStream(string $streamId): bool
    {
        $stream = $this->getStream($streamId);
        if ($stream === null) {
            Logger::error("Stream not found for finalization: {$streamId}");
            return false;
        }

        if ($stream->getStatus() !== StreamStatus::UPLOADING) {
            Logger::warning("Stream {$streamId} is not in uploading state for finalization");
            return false;
        }

        try {
            // Finalize memory-mapped file
            $mmapFile = $stream->getMmapFile();
            if ($mmapFile->finalize($stream->getTotalSize())) {
                $stream->setStatus(StreamStatus::READY);
                $stream->updateAccessTime();

                Logger::info("Finalized stream: {$streamId} with {$stream->getTotalSize()} bytes");
                return true;
            } else {
                Logger::error("Failed to finalize memory-mapped file for stream {$streamId}");
                return false;
            }

        } catch (\Exception $e) {
            Logger::error("Error finalizing stream {$streamId}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Clean up old streams (older than maxAgeHours).
     *
     * @param int $maxAgeHours Maximum age in hours (default 24)
     */
    public function cleanupOldStreams(int $maxAgeHours = 24): void
    {
        $now = new \DateTime();
        $cutoff = new \DateInterval("PT{$maxAgeHours}H");

        $toRemove = [];
        foreach ($this->streams as $streamId => $context) {
            $age = $now->diff($context->getLastAccessedAt());
            $ageHours = ($age->h + $age->days * 24);
            if ($ageHours > $maxAgeHours) {
                $toRemove[] = $streamId;
            }
        }

        foreach ($toRemove as $streamId) {
            Logger::info("Cleaning up old stream: {$streamId}");
            $this->deleteStream($streamId);
        }
    }

    /**
     * Get cache file path for a stream.
     *
     * @param string $streamId Unique identifier for the stream
     * @return string Cache file path
     */
    private function getCachePath(string $streamId): string
    {
        return $this->cacheDirectory . DIRECTORY_SEPARATOR . $streamId . '.cache';
    }
}

