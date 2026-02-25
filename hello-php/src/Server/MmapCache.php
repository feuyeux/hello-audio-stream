<?php

declare(strict_types=1);

namespace AudioStream\Server;

final class MmapCache
{
    private int $size = 0;
    private bool $open = false;
    /** @var resource|null */
    private $handle = null;

    public function __construct(
        private readonly string $path,
    ) {}

    public function __destruct()
    {
        $this->close();
    }

    public function create(): bool
    {
        $this->close();
        $dir = dirname($this->path);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        if (file_exists($this->path)) {
            @unlink($this->path);
        }
        $handle = @fopen($this->path, 'c+b');
        if ($handle === false) {
            return false;
        }
        $this->handle = $handle;
        $this->size = 0;
        $this->open = true;
        return true;
    }

    public function write(int $offset, string $data): int
    {
        $len = strlen($data);
        if ($len === 0 || !$this->open || $this->handle === null) {
            return 0;
        }

        $needed = $offset + $len;
        if ($needed > $this->size) {
            if (!@ftruncate($this->handle, $needed)) {
                return 0;
            }
            $this->size = $needed;
        }

        @flock($this->handle, LOCK_EX);
        @fseek($this->handle, $offset);
        $written = 0;
        while ($written < $len) {
            $w = @fwrite($this->handle, substr($data, $written));
            if ($w === false || $w === 0) {
                break;
            }
            $written += $w;
        }
        @flock($this->handle, LOCK_UN);

        return $written;
    }

    public function read(int $offset, int $length): string
    {
        if (!$this->open || $this->handle === null) {
            return '';
        }
        if ($offset >= $this->size || $length <= 0) {
            return '';
        }

        $actual = min($length, $this->size - $offset);
        @flock($this->handle, LOCK_SH);
        @fseek($this->handle, $offset);
        $data = @fread($this->handle, $actual);
        @flock($this->handle, LOCK_UN);

        return $data === false ? '' : $data;
    }

    public function finalize(int $finalSize): bool
    {
        if (!$this->open || $this->handle === null) {
            return false;
        }
        if (!@ftruncate($this->handle, $finalSize)) {
            return false;
        }
        @fflush($this->handle);
        $this->size = $finalSize;
        return true;
    }

    public function close(): void
    {
        if ($this->handle !== null) {
            @fclose($this->handle);
            $this->handle = null;
        }
        $this->open = false;
    }

    public function delete(): void
    {
        $this->close();
        if (file_exists($this->path)) {
            @unlink($this->path);
        }
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
        return $this->open;
    }
}
