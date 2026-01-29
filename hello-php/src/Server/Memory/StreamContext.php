<?php

/**
 * Stream context for managing active audio streams.
 * Contains stream metadata and cache file handle.
 * Matches Python StreamContext and Java StreamContext functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

/**
 * Stream status enumeration
 */
class StreamStatus
{
    public const UPLOADING = 'UPLOADING';
    public const READY = 'READY';
    public const ERROR = 'ERROR';
}

/**
 * Stream context containing metadata and state for a single stream.
 */
class StreamContext
{
    private string $streamId;
    private string $cachePath;
    private $mmapFile;
    private int $currentOffset;
    private int $totalSize;
    private \DateTime $createdAt;
    private \DateTime $lastAccessedAt;
    private string $status;

    /**
     * Create a new StreamContext.
     *
     * @param string $streamId Unique identifier for the stream
     * @param string $cachePath Path to the cache file
     */
    public function __construct(string $streamId, string $cachePath = '')
    {
        $this->streamId = $streamId;
        $this->cachePath = $cachePath;
        $this->mmapFile = null;
        $this->currentOffset = 0;
        $this->totalSize = 0;
        $this->createdAt = new \DateTime();
        $this->lastAccessedAt = new \DateTime();
        $this->status = StreamStatus::UPLOADING;
    }

    /**
     * Update last accessed timestamp
     */
    public function updateAccessTime(): void
    {
        $this->lastAccessedAt = new \DateTime();
    }

    /**
     * Get stream ID
     *
     * @return string Stream ID
     */
    public function getStreamId(): string
    {
        return $this->streamId;
    }

    /**
     * Get cache path
     *
     * @return string Cache file path
     */
    public function getCachePath(): string
    {
        return $this->cachePath;
    }

    /**
     * Get current offset
     *
     * @return int Current offset in bytes
     */
    public function getCurrentOffset(): int
    {
        return $this->currentOffset;
    }

    /**
     * Set current offset
     *
     * @param int $offset New offset in bytes
     */
    public function setCurrentOffset(int $offset): void
    {
        $this->currentOffset = $offset;
    }

    /**
     * Get total size
     *
     * @return int Total size in bytes
     */
    public function getTotalSize(): int
    {
        return $this->totalSize;
    }

    /**
     * Set total size
     *
     * @param int $size Total size in bytes
     */
    public function setTotalSize(int $size): void
    {
        $this->totalSize = $size;
    }

    /**
     * Get created at timestamp
     *
     * @return \DateTime Creation timestamp
     */
    public function getCreatedAt(): \DateTime
    {
        return $this->createdAt;
    }

    /**
     * Get last accessed at timestamp
     *
     * @return \DateTime Last access timestamp
     */
    public function getLastAccessedAt(): \DateTime
    {
        return $this->lastAccessedAt;
    }

    /**
     * Get stream status
     *
     * @return string Current status
     */
    public function getStatus(): string
    {
        return $this->status;
    }

    /**
     * Set stream status
     *
     * @param string $status New status
     */
    public function setStatus(string $status): void
    {
        $this->status = $status;
    }

    /**
     * Get memory-mapped file handle
     *
     * @return mixed File handle
     */
    public function getMmapFile()
    {
        return $this->mmapFile;
    }

    /**
     * Set memory-mapped file handle
     *
     * @param mixed $file File handle
     */
    public function setMmapFile($file): void
    {
        $this->mmapFile = $file;
    }
}
