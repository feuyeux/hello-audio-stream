<?php

/**
 * Memory pool manager for efficient buffer reuse.
 * Pre-allocates buffers to minimize allocation overhead.
 * Implemented as a singleton to ensure a single shared pool across all streams.
 * Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

use AudioStreamClient\Logger;

/**
 * Memory pool manager singleton.
 */
class MemoryPoolManager
{
    private static ?self $instance = null;
    private int $bufferSize;
    private int $poolSize;
    private array $availableBuffers;
    private int $totalBuffers;
    

    /**
     * Get the singleton instance of MemoryPoolManager.
     *
     * @param int $bufferSize Size of each buffer in bytes (default 65536)
     * @param int $poolSize Number of buffers to pre-allocate (default 100)
     * @return self The singleton instance
     */
    public static function getInstance(
        int $bufferSize = 65536,
        int $poolSize = 100
    ): self {
        if (self::$instance === null) {
            self::$instance = new self($bufferSize, $poolSize);
        }
        return self::$instance;
    }

    /**
     * Private constructor for singleton pattern.
     *
     * @param int $bufferSize Size of each buffer in bytes
     * @param int $poolSize Number of buffers to pre-allocate
     */
    private function __construct(int $bufferSize, int $poolSize)
    {
        $this->bufferSize = $bufferSize;
        $this->poolSize = $poolSize;
        $this->availableBuffers = [];
        $this->totalBuffers = 0;

        // Pre-allocate buffers
        for ($i = 0; $i < $poolSize; $i++) {
            $buffer = str_repeat("\0", $bufferSize);
            $this->availableBuffers[] = $buffer;
            $this->totalBuffers++;
        }

        Logger::info("MemoryPoolManager initialized with {$poolSize} buffers of {$bufferSize} bytes");
    }

    /**
     * Acquire a buffer from the pool.
     * If pool is exhausted, allocates a new buffer dynamically.
     *
     * @return string A buffer of size bufferSize
     */
    public function acquireBuffer(): string
    {
        if (count($this->availableBuffers) > 0) {
            $buffer = array_shift($this->availableBuffers);
            Logger::debug("Acquired buffer from pool (" . count($this->availableBuffers) . " remaining)");
            return $buffer;
        } else {
            // Pool exhausted, allocate new buffer
            $buffer = str_repeat("\0", $this->bufferSize);
            $this->totalBuffers++;
            Logger::debug("Pool exhausted, allocated new buffer (total: {$this->totalBuffers})");
            return $buffer;
        }
    }

    /**
     * Release a buffer back to the pool.
     *
     * @param string $buffer The buffer to release
     */
    public function releaseBuffer(string $buffer): void
    {
        if (strlen($buffer) !== $this->bufferSize) {
            Logger::warning("Buffer size mismatch: expected {$this->bufferSize}, got " . strlen($buffer));
            return;
        }

        // Clear buffer before returning to pool
        $buffer = str_repeat("\0", $this->bufferSize);

        // Only return to pool if we haven't exceeded pool size
        if (count($this->availableBuffers) < $this->poolSize) {
            $this->availableBuffers[] = $buffer;
        }

        Logger::debug("Released buffer to pool (" . count($this->availableBuffers) . " available)");
    }

    /**
     * Get the number of available buffers in the pool.
     *
     * @return int Number of available buffers
     */
    public function getAvailableBuffers(): int
    {
        return count($this->availableBuffers);
    }

    /**
     * Get the total number of buffers (available + in-use).
     *
     * @return int Total number of buffers
     */
    public function getTotalBuffers(): int
    {
        return $this->poolSize;
    }

    /**
     * Get the buffer size.
     *
     * @return int Buffer size in bytes
     */
    public function getBufferSize(): int
    {
        return $this->bufferSize;
    }
}

