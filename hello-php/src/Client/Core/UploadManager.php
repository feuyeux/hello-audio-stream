<?php

namespace AudioStreamClient\Core;

use AudioStreamClient\Logger;
use AudioStreamClient\Util\StreamIdGenerator;

class UploadManager
{
    private const UPLOAD_CHUNK_SIZE = 8192; // 8KB to avoid WebSocket frame fragmentation

    public static function upload(WebSocketClient $ws, string $filePath): string
    {
        $streamId = StreamIdGenerator::generateShort();
        $fileSize = FileManager::getFileSize($filePath);

        Logger::info('========================================');
        Logger::info('Phase 1: Upload');
        Logger::info('========================================');
        Logger::info('Stream ID: ' . $streamId);
        Logger::info('File size: ' . $fileSize . ' bytes');

        // Send START message
        $ws->sendText(['type' => 'START', 'streamId' => $streamId]);

        // Wait for STARTED response from server
        $startAck = $ws->receiveText();
        if (strpos($startAck, '"type":"STARTED"') === false) {
            throw new \Exception('Failed to receive STARTED');
        }
        Logger::debug('Received START_ACK');

        // Read all file data upfront
        $fileData = file_get_contents($filePath);
        $offset = 0;
        $lastProgress = 0;

        // Send all chunks
        while ($offset < $fileSize) {
            $chunkSize = min(self::UPLOAD_CHUNK_SIZE, $fileSize - $offset);
            $chunk = substr($fileData, $offset, $chunkSize);

            $ws->sendBinary($chunk);
            $offset += $chunkSize;

            // Report progress
            $progress = (int)(($offset / $fileSize) * 100);
            if ($progress >= $lastProgress + 25 && $progress > $lastProgress) {
                Logger::info('Upload progress: ' . $progress . '% (' . $offset . ' / ' . $fileSize . ' bytes)');
                $lastProgress = (int)($progress / 25) * 25;
            }
        }

        Logger::info('Upload progress: 100% (' . $fileSize . ' / ' . $fileSize . ' bytes)');

        // Send STOP message
        $ws->sendText(['type' => 'STOP', 'streamId' => $streamId]);

        // Wait for STOPPED response from server
        $stopAck = $ws->receiveText();
        if (strpos($stopAck, '"type":"STOPPED"') === false) {
            throw new \Exception('Failed to receive STOPPED');
        }
        Logger::debug('Received STOP_ACK');
        Logger::info('Upload completed');

        return $streamId;
    }
}
