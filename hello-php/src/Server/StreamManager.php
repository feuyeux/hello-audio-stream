<?php

declare(strict_types=1);

namespace AudioStream\Server;

class Stream
{
    public int $offset = 0;
    public float $lastAccess;
    public string $status = 'UPLOADING';

    public function __construct(
        public readonly string $id,
        public readonly MmapCache $cache,
        public readonly float $created,
    ) {
        $this->lastAccess = $this->created;
    }

    public function touch(): void
    {
        $this->lastAccess = microtime(true);
    }
}

final class StreamManager
{
    /** @var array<string, Stream> */
    private array $streams = [];
    private readonly float $maxIdleSeconds;
    private readonly float $maxUploadingSeconds;

    public function __construct(
        private readonly string $cacheDir = 'cache',
        private readonly int $maxStreams = 1000,
        float $maxIdleHours = 24.0,
        float $maxUploadingHours = 1.0,
    ) {
        $this->maxIdleSeconds = $maxIdleHours * 3600;
        $this->maxUploadingSeconds = $maxUploadingHours * 3600;
        if (!is_dir($cacheDir)) {
            mkdir($cacheDir, 0755, true);
        }
    }

    public function create(string $streamId): bool
    {
        if (isset($this->streams[$streamId])) {
            return false;
        }
        if (count($this->streams) >= $this->maxStreams) {
            return false;
        }

        $path = $this->cacheDir . DIRECTORY_SEPARATOR . $streamId . '.cache';
        $cache = new MmapCache($path);
        if (!$cache->create()) {
            return false;
        }

        $this->streams[$streamId] = new Stream($streamId, $cache, microtime(true));
        return true;
    }

    public function write(string $streamId, string $data): bool
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream === null || $stream->status !== 'UPLOADING') {
            return false;
        }

        $written = $stream->cache->write($stream->offset, $data);
        if ($written <= 0) {
            return false;
        }

        $stream->offset += $written;
        $stream->touch();
        return true;
    }

    public function complete(string $streamId): bool
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream === null || $stream->status !== 'UPLOADING') {
            return false;
        }

        if (!$stream->cache->finalize($stream->offset)) {
            return false;
        }

        $stream->status = 'READY';
        $stream->touch();
        return true;
    }

    public function read(string $streamId, int $offset, int $length): string
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream === null) {
            return '';
        }

        $stream->touch();
        return $stream->cache->read($offset, $length);
    }

    public function delete(string $streamId): bool
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream === null) {
            return false;
        }

        $stream->cache->delete();
        unset($this->streams[$streamId]);
        return true;
    }

    public function markError(string $streamId): void
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream !== null && $stream->status === 'UPLOADING') {
            $stream->status = 'ERROR';
        }
    }

    /** @return array{status: string, size: int}|null */
    public function statusOf(string $streamId): ?array
    {
        $stream = $this->streams[$streamId] ?? null;
        if ($stream === null) {
            return null;
        }

        $stream->touch();
        return [
            'status' => $stream->status,
            'size' => $stream->offset,
        ];
    }

    /** @return string[] */
    public function list(): array
    {
        return array_keys($this->streams);
    }

    public function cleanup(): int
    {
        $now = microtime(true);
        $removed = 0;
        foreach ($this->streams as $id => $stream) {
            $idle = $now - $stream->lastAccess;
            $shouldRemove = match ($stream->status) {
                'UPLOADING' => $idle > $this->maxUploadingSeconds,
                'ERROR' => true,
                default => $idle > $this->maxIdleSeconds,
            };
            if ($shouldRemove) {
                $this->delete($id);
                $removed++;
            }
        }
        return $removed;
    }

    /** @return array{total: int, uploading: int, ready: int, error: int} */
    public function stats(): array
    {
        return [
            'total' => count($this->streams),
            'uploading' => count(array_filter($this->streams, fn(Stream $s) => $s->status === 'UPLOADING')),
            'ready' => count(array_filter($this->streams, fn(Stream $s) => $s->status === 'READY')),
            'error' => count(array_filter($this->streams, fn(Stream $s) => $s->status === 'ERROR')),
        ];
    }
}
