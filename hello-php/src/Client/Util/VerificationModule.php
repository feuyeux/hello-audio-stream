<?php

namespace AudioStreamClient\Util;

use AudioStreamClient\Core\FileManager;
use AudioStreamClient\Logger;

class VerificationModule
{
    public static function verify(string $originalPath, string $downloadedPath): array
    {
        Logger::info('========================================');
        Logger::info('Phase 3: Verification');
        Logger::info('========================================');

        $originalSize = FileManager::getFileSize($originalPath);
        $downloadedSize = FileManager::getFileSize($downloadedPath);

        Logger::info('Computing checksums...');
        $originalChecksum = FileManager::computeSha256($originalPath);
        $downloadedChecksum = FileManager::computeSha256($downloadedPath);

        Logger::info('Original file:');
        Logger::info('  Size: ' . $originalSize . ' bytes');
        Logger::info('  SHA-256: ' . $originalChecksum);

        Logger::info('Downloaded file:');
        Logger::info('  Size: ' . $downloadedSize . ' bytes');
        Logger::info('  SHA-256: ' . $downloadedChecksum);

        $sizeMatch = $originalSize === $downloadedSize;
        $checksumMatch = strcasecmp($originalChecksum, $downloadedChecksum) === 0;
        $passed = $sizeMatch && $checksumMatch;

        if ($passed) {
            Logger::info('✓ Verification PASSED');
        } else {
            Logger::error('✗ Verification FAILED');
            if (!$sizeMatch) {
                Logger::error('  Size mismatch: ' . $originalSize . ' != ' . $downloadedSize);
            }
            if (!$checksumMatch) {
                Logger::error('  Checksum mismatch');
            }
        }

        return [
            'passed' => $passed,
            'originalSize' => $originalSize,
            'downloadedSize' => $downloadedSize,
            'originalChecksum' => $originalChecksum,
            'downloadedChecksum' => $downloadedChecksum,
        ];
    }
}
