<?php

/**
 * Cross-platform cache file abstraction.
 * - macOS uses a dedicated file I/O path to avoid Linux-specific libc assumptions.
 * - Linux/Windows/Other use a portable generic file I/O path.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

use AudioStreamClient\Logger;

class MemoryMappedCache
{
    private string $path;
    private int $size = 0;
    private bool $_isOpen = false;
    private string $platform;

    /** @var resource|null */
    private $handle = null;

    public function __construct(string $filePath)
    {
        $this->path = $filePath;
        $this->platform = self::detectPlatform();
    }

    public function __destruct()
    {
        $this->close();
    }

    public function create(string $filePath, int $initialSize = 0): bool
    {
        return $this->isMacos()
            ? $this->createMacos($filePath, $initialSize)
            : $this->createGeneric($filePath, $initialSize);
    }

    public function open(string $filePath): bool
    {
        return $this->isMacos()
            ? $this->openMacos($filePath)
            : $this->openGeneric($filePath);
    }

    public function close(): void
    {
        if ($this->handle !== null) {
            @fclose($this->handle);
            $this->handle = null;
        }
        $this->_isOpen = false;
    }

    public function write(int $offset, string $data): int
    {
        $dataLen = strlen($data);
        if ($dataLen === 0) {
            return 0;
        }

        if (!$this->_isOpen) {
            if (!$this->create($this->path, $offset + $dataLen)) {
                return 0;
            }
        }

        if ($offset + $dataLen > $this->size && !$this->resize($offset + $dataLen)) {
            Logger::error('Failed to resize file for write operation');
            return 0;
        }

        if ($this->lockExclusive() && @fseek($this->handle, $offset) === 0) {
            $written = $this->writeAll($data);
            $this->unlock();
        } else {
            $this->unlock();
            Logger::error("Failed to seek to offset {$offset}");
            return 0;
        }

        if ($written <= 0) {
            Logger::error("Failed to write to {$this->path}");
            return 0;
        }

        $endPos = $offset + $written;
        if ($endPos > $this->size) {
            $this->size = $endPos;
        }

        return $written;
    }

    public function read(int $offset, int $length): string
    {
        if (!$this->_isOpen) {
            if (!$this->open($this->path)) {
                return '';
            }
        }

        if ($offset >= $this->size || $length <= 0) {
            return '';
        }

        $actualLength = min($length, $this->size - $offset);

        if (!$this->lockShared() || @fseek($this->handle, $offset) !== 0) {
            $this->unlock();
            Logger::error("Failed to seek to offset {$offset}");
            return '';
        }

        $data = @fread($this->handle, $actualLength);
        $this->unlock();

        return $data === false ? '' : $data;
    }

    public function resize(int $newSize): bool
    {
        if (!$this->_isOpen || $this->handle === null) {
            return false;
        }

        if ($newSize === $this->size) {
            return true;
        }

        if (!$this->lockExclusive()) {
            return false;
        }

        $ok = @ftruncate($this->handle, $newSize);
        $this->unlock();

        if (!$ok) {
            Logger::error("Failed to resize file {$this->path} to {$newSize}");
            return false;
        }

        $this->size = $newSize;
        Logger::debug("Resized file {$this->path} to {$newSize} bytes");
        return true;
    }

    public function flush(): bool
    {
        if (!$this->_isOpen || $this->handle === null) {
            return false;
        }

        if (!$this->lockExclusive()) {
            return false;
        }

        $ok = @fflush($this->handle);
        $this->unlock();

        if ($ok) {
            Logger::debug("Flushed file: {$this->path}");
        }
        return (bool)$ok;
    }

    public function finalize(int $finalSize): bool
    {
        if (!$this->_isOpen) {
            return false;
        }

        if (!$this->resize($finalSize)) {
            return false;
        }

        $this->flush();
        Logger::debug("Finalized file: {$this->path} size={$finalSize}");
        return true;
    }

    public function getSize(): int
    {
        return $this->size;
    }

    public function getPath(): string
    {
        return $this->path;
    }

    public function isOpen(): bool
    {
        return $this->_isOpen;
    }

    private function createMacos(string $filePath, int $initialSize): bool
    {
        $this->close();
        $this->path = $filePath;

        if (file_exists($filePath) && !@unlink($filePath)) {
            Logger::error("Failed to remove existing file: {$filePath}");
            return false;
        }

        // macOS dedicated path: use w+b and disable stdio buffering.
        $handle = @fopen($filePath, 'w+b');
        if ($handle === false) {
            Logger::error("Failed to create file (macOS): {$filePath}");
            return false;
        }
        @stream_set_write_buffer($handle, 0);

        if ($initialSize > 0 && !@ftruncate($handle, $initialSize)) {
            fclose($handle);
            Logger::error("Failed to set initial size for (macOS): {$filePath}");
            return false;
        }

        $this->handle = $handle;
        $this->size = max(0, $initialSize);
        $this->_isOpen = true;

        Logger::debug("Created macOS cache file: {$this->path} size={$this->size}");
        return true;
    }

    private function createGeneric(string $filePath, int $initialSize): bool
    {
        $this->close();
        $this->path = $filePath;

        if (file_exists($filePath) && !@unlink($filePath)) {
            Logger::error("Failed to remove existing file: {$filePath}");
            return false;
        }

        $handle = @fopen($filePath, 'c+b');
        if ($handle === false) {
            Logger::error("Failed to create file: {$filePath}");
            return false;
        }

        if ($initialSize > 0 && !@ftruncate($handle, $initialSize)) {
            fclose($handle);
            Logger::error("Failed to set initial size for: {$filePath}");
            return false;
        }

        $this->handle = $handle;
        $this->size = max(0, $initialSize);
        $this->_isOpen = true;

        Logger::debug("Created cache file: {$this->path} size={$this->size}");
        return true;
    }

    private function openMacos(string $filePath): bool
    {
        $this->close();
        $this->path = $filePath;

        if (!file_exists($filePath)) {
            Logger::error("File does not exist: {$filePath}");
            return false;
        }

        $handle = @fopen($filePath, 'r+b');
        if ($handle === false) {
            Logger::error("Failed to open file (macOS): {$filePath}");
            return false;
        }
        @stream_set_write_buffer($handle, 0);

        $fileSize = filesize($filePath);
        $this->handle = $handle;
        $this->size = $fileSize === false ? 0 : (int)$fileSize;
        $this->_isOpen = true;

        Logger::debug("Opened macOS cache file: {$this->path} size={$this->size}");
        return true;
    }

    private function openGeneric(string $filePath): bool
    {
        $this->close();
        $this->path = $filePath;

        if (!file_exists($filePath)) {
            Logger::error("File does not exist: {$filePath}");
            return false;
        }

        $handle = @fopen($filePath, 'r+b');
        if ($handle === false) {
            Logger::error("Failed to open file: {$filePath}");
            return false;
        }

        $fileSize = filesize($filePath);
        $this->handle = $handle;
        $this->size = $fileSize === false ? 0 : (int)$fileSize;
        $this->_isOpen = true;

        Logger::debug("Opened cache file: {$this->path} size={$this->size}");
        return true;
    }

    private function writeAll(string $data): int
    {
        $total = 0;
        $len = strlen($data);

        while ($total < $len) {
            $chunk = substr($data, $total);
            $written = @fwrite($this->handle, $chunk);
            if ($written === false || $written === 0) {
                break;
            }
            $total += $written;
        }

        return $total;
    }

    private function lockExclusive(): bool
    {
        return $this->handle !== null && @flock($this->handle, LOCK_EX);
    }

    private function lockShared(): bool
    {
        return $this->handle !== null && @flock($this->handle, LOCK_SH);
    }

    private function unlock(): void
    {
        if ($this->handle !== null) {
            @flock($this->handle, LOCK_UN);
        }
    }

    private static function detectPlatform(): string
    {
        $family = strtolower(PHP_OS_FAMILY);
        return match ($family) {
            'darwin' => 'macos',
            'linux' => 'linux',
            'windows' => 'windows',
            default => 'other',
        };
    }

    private function isMacos(): bool
    {
        return $this->platform === 'macos';
    }
}
