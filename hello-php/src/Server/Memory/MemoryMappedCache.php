<?php

/**
 * Memory-mapped cache for efficient file I/O.
 * Provides write, read, resize, and finalize operations.
 * Matches Python MmapCache functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

use AudioStreamClient\Logger;

const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
const MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024; // 2GB

/**
 * Memory-mapped cache implementation.
 */
class MemoryMappedCache
{
    private string $path;
    private $fileHandle;
    private int $size;
    private bool $isOpen;

    /**
     * Create a new MemoryMappedCache.
     *
     * @param string $filePath Path to the cache file
     */
    public function __construct(string $filePath)
    {
        $this->path = $filePath;
        $this->fileHandle = null;
        $this->size = 0;
        $this->isOpen = false;
    }

    /**
     * Create a new memory-mapped file.
     *
     * @param string $filePath Path to the file
     * @param int $initialSize Initial size in bytes
     * @return bool True if successful
     */
    public function create(string $filePath, int $initialSize = 0): bool
    {
        // Remove existing file
        if (file_exists($filePath)) {
            unlink($filePath);
        }

        // Create and open file
        $this->fileHandle = fopen($filePath, 'c+b');
        if ($this->fileHandle === false) {
            Logger::error("Error creating file {$filePath}");
            return false;
        }

        if ($initialSize > 0) {
            // Write zeros to allocate space
            $buffer = str_repeat("\0", $initialSize);
            fwrite($this->fileHandle, $buffer);
            $this->size = $initialSize;
        } else {
            $this->size = 0;
        }

        $this->isOpen = true;
        Logger::debug("Created mmap file: {$filePath} with size: {$initialSize}");
        return true;
    }

    /**
     * Open an existing memory-mapped file.
     *
     * @param string $filePath Path to the file
     * @return bool True if successful
     */
    public function open(string $filePath): bool
    {
        if (!file_exists($filePath)) {
            Logger::error("File does not exist: {$filePath}");
            return false;
        }

        $this->fileHandle = fopen($filePath, 'r+b');
        if ($this->fileHandle === false) {
            Logger::error("Error opening file {$filePath}");
            return false;
        }

        $this->size = filesize($filePath);
        $this->isOpen = true;
        Logger::debug("Opened mmap file: {$filePath} with size: {$this->size}");
        return true;
    }

    /**
     * Close the memory-mapped file.
     */
    public function close(): void
    {
        if ($this->isOpen && $this->fileHandle !== null) {
            fclose($this->fileHandle);
            $this->fileHandle = null;
            $this->isOpen = false;
        }
    }

    /**
     * Write data to the file.
     *
     * @param int $offset Offset to write to
     * @param string $data Data to write
     * @return int Number of bytes written
     */
    public function write(int $offset, string $data): int
    {
        if (!$this->isOpen || $this->fileHandle === null) {
            $initialSize = $offset + strlen($data);
            if (!$this->create($this->path, $initialSize)) {
                return 0;
            }
        }

        $requiredSize = $offset + strlen($data);
        if ($requiredSize > $this->size) {
            if (!$this->resize($requiredSize)) {
                Logger::error('Failed to resize file for write operation');
                return 0;
            }
        }

        // Seek to offset
        fseek($this->fileHandle, $offset);

        // Write data
        $written = fwrite($this->fileHandle, $data);
        if ($written === false) {
            Logger::error("Error writing to file {$this->path}");
            return 0;
        }

        return $written;
    }

    /**
     * Read data from the file.
     *
     * @param int $offset Offset to read from
     * @param int $length Number of bytes to read
     * @return string Data read, or empty string on error
     */
    public function read(int $offset, int $length): string
    {
        if (!$this->isOpen || $this->fileHandle === null) {
            if (!$this->open($this->path)) {
                Logger::error("Failed to open file for reading: {$this->path}");
                return '';
            }
        }

        if ($offset >= $this->size) {
            return '';
        }

        // Seek to offset
        fseek($this->fileHandle, $offset);

        // Read data
        $actualLength = min($length, $this->size - $offset);
        $data = fread($this->fileHandle, $actualLength);
        if ($data === false) {
            Logger::error("Error reading from file {$this->path}");
            return '';
        }

        Logger::debug("Read " . strlen($data) . " bytes from {$this->path} at offset {$offset}");
        return $data;
    }

    /**
     * Get the size of the file.
     *
     * @return int File size in bytes
     */
    public function getSize(): int
    {
        return $this->size;
    }

    /**
     * Get the path of the file.
     *
     * @return string File path
     */
    public function getPath(): string
    {
        return $this->path;
    }

    /**
     * Check if the file is open.
     *
     * @return bool True if open
     */
    public function getIsOpen(): bool
    {
        return $this->isOpen;
    }

    /**
     * Resize the file to a new size.
     *
     * @param int $newSize New size in bytes
     * @return bool True if successful
     */
    private function resize(int $newSize): bool
    {
        if (!$this->isOpen) {
            Logger::error("File not open for resize: {$this->path}");
            return false;
        }

        if ($newSize === $this->size) {
            return true;
        }

        if ($newSize < $this->size) {
            // Truncate
            ftruncate($this->fileHandle, $newSize);
        } else {
            // Expand - write zeros at the end
            $buffer = str_repeat("\0", $newSize - $this->size);
            fseek($this->fileHandle, $this->size);
            fwrite($this->fileHandle, $buffer);
        }

        $this->size = $newSize;
        Logger::debug("Resized file {$this->path} to {$newSize} bytes");
        return true;
    }

    /**
     * Finalize the file to its final size.
     *
     * @param int $finalSize Final size in bytes
     * @return bool True if successful
     */
    public function finalize(int $finalSize): bool
    {
        if (!$this->isOpen) {
            Logger::warning("File not open for finalization: {$this->path}");
            return false;
        }

        if (!$this->resize($finalSize)) {
            Logger::error("Failed to resize file during finalization: {$this->path}");
            return false;
        }

        // Sync to disk
        fflush($this->fileHandle);

        Logger::debug("Finalized file: {$this->path} with size: {$finalSize}");
        return true;
    }
}

