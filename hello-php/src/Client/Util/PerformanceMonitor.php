<?php

namespace AudioStreamClient\Util;

use AudioStreamClient\Logger;

class PerformanceMonitor
{
    private int $uploadStartMs = 0;
    private int $uploadEndMs = 0;
    private int $downloadStartMs = 0;
    private int $downloadEndMs = 0;
    private int $fileSize = 0;

    public function setFileSize(int $size): void
    {
        $this->fileSize = $size;
    }

    public function startUpload(): void
    {
        $this->uploadStartMs = (int)(microtime(true) * 1000);
    }

    public function endUpload(): void
    {
        $this->uploadEndMs = (int)(microtime(true) * 1000);
    }

    public function startDownload(): void
    {
        $this->downloadStartMs = (int)(microtime(true) * 1000);
    }

    public function endDownload(): void
    {
        $this->downloadEndMs = (int)(microtime(true) * 1000);
    }

    public function getReport(): array
    {
        $uploadDurationMs = $this->uploadEndMs - $this->uploadStartMs;
        $downloadDurationMs = $this->downloadEndMs - $this->downloadStartMs;
        $totalDurationMs = $this->downloadEndMs - $this->uploadStartMs;

        $uploadThroughputMbps = $this->calculateThroughput($this->fileSize, $uploadDurationMs);
        $downloadThroughputMbps = $this->calculateThroughput($this->fileSize, $downloadDurationMs);
        $averageThroughputMbps = $this->calculateThroughput($this->fileSize * 2, $totalDurationMs);

        return [
            'uploadDurationMs' => $uploadDurationMs,
            'uploadThroughputMbps' => $uploadThroughputMbps,
            'downloadDurationMs' => $downloadDurationMs,
            'downloadThroughputMbps' => $downloadThroughputMbps,
            'totalDurationMs' => $totalDurationMs,
            'averageThroughputMbps' => $averageThroughputMbps,
        ];
    }

    public function printReport(array $report): void
    {
        Logger::info('========================================');
        Logger::info('Phase 4: Performance Report');
        Logger::info('========================================');
        Logger::info('Upload:');
        Logger::info('  Duration: ' . $report['uploadDurationMs'] . ' ms');
        Logger::info('  Throughput: ' . number_format($report['uploadThroughputMbps'], 2) . ' Mbps');
        Logger::info('Download:');
        Logger::info('  Duration: ' . $report['downloadDurationMs'] . ' ms');
        Logger::info('  Throughput: ' . number_format($report['downloadThroughputMbps'], 2) . ' Mbps');
        Logger::info('Total:');
        Logger::info('  Duration: ' . $report['totalDurationMs'] . ' ms');
        Logger::info('  Average throughput: ' . number_format($report['averageThroughputMbps'], 2) . ' Mbps');
        Logger::info('========================================');
    }

    private function calculateThroughput(int $bytes, int $durationMs): float
    {
        if ($durationMs == 0) {
            return 0.0;
        }
        $bits = $bytes * 8.0;
        $seconds = $durationMs / 1000.0;
        return $bits / $seconds / 1000000.0;
    }
}
