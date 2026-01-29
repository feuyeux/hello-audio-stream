<?php

namespace AudioStreamClient\Core;

class FileManager
{
    private const CHUNK_SIZE = 65536; // 64KB

    public static function readChunk(string $path, int $offset, int $size): string
    {
        $handle = fopen($path, 'rb');
        if ($handle === false) {
            throw new \Exception("Failed to open file: $path");
        }

        fseek($handle, $offset);
        $data = fread($handle, $size);
        fclose($handle);

        return $data;
    }

    public static function writeChunk(string $path, string $data, bool $append = true): void
    {
        $dir = dirname($path);
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }

        $mode = $append && file_exists($path) ? 'ab' : 'wb';
        $handle = fopen($path, $mode);
        if ($handle === false) {
            throw new \Exception("Failed to open file for writing: $path");
        }

        fwrite($handle, $data);
        fclose($handle);
    }

    public static function computeSha256(string $path): string
    {
        return hash_file('sha256', $path);
    }

    public static function getFileSize(string $path): int
    {
        return filesize($path);
    }

    public static function deleteFile(string $path): void
    {
        if (file_exists($path)) {
            unlink($path);
        }
    }
}
