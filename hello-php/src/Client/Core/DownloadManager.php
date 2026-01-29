<?php

namespace AudioStreamClient\Core;

use AudioStreamClient\Logger;

class DownloadManager
{
    private const DOWNLOAD_CHUNK_SIZE = 8192; // 8KB per GET request

    public static function download(WebSocketClient $ws, string $streamId, string $outputPath, int $fileSize): void
    {
        Logger::info('========================================');
        Logger::info('Phase 2: Download');
        Logger::info('========================================');
        Logger::info('Output path: ' . $outputPath);
        Logger::info('Expected size: ' . $fileSize . ' bytes');

        // Delete output file if it exists
        FileManager::deleteFile($outputPath);

        $offset = 0;
        $lastProgress = 0;

        while ($offset < $fileSize) {
            $length = min(self::DOWNLOAD_CHUNK_SIZE, $fileSize - $offset);

            // Send GET message
            $ws->sendText([
                'type' => 'GET',
                'streamId' => $streamId,
                'offset' => $offset,
                'length' => $length,
            ]);

            // Receive binary data
            $data = $ws->receiveBinary();
            if ($data === null || $data === '') {
                throw new \Exception('Failed to receive data at offset ' . $offset);
            }

            // Only write the amount we requested, not more
            $actualLength = min(strlen($data), $fileSize - $offset);
            $dataToWrite = substr($data, 0, $actualLength);
            
            // Write to file
            FileManager::writeChunk($outputPath, $dataToWrite, true);
            $offset += $actualLength;

            // Report progress
            $progress = (int)(($offset / $fileSize) * 100);
            if ($progress >= $lastProgress + 25 && $progress > $lastProgress) {
                Logger::info('Download progress: ' . $progress . '% (' . $offset . ' / ' . $fileSize . ' bytes)');
                $lastProgress = (int)($progress / 25) * 25;
            }
        }

        Logger::info('Download progress: 100% (' . $fileSize . ' / ' . $fileSize . ' bytes)');
        Logger::info('Download completed');
    }
}
