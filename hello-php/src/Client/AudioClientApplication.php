<?php

namespace AudioStreamClient;

use AudioStreamClient\Core\WebSocketClient;
use AudioStreamClient\Core\FileManager;
use AudioStreamClient\Core\UploadManager;
use AudioStreamClient\Core\DownloadManager;
use AudioStreamClient\Util\PerformanceMonitor;
use AudioStreamClient\Util\VerificationModule;

/**
 * Audio client application entry point.
 * Coordinates upload, download, and verification operations.
 */
class AudioClientApplication
{
    private array $config;
    private PerformanceMonitor $performance;

    /**
     * Create a new AudioClientApplication.
     *
     * @param array $config Configuration array with inputPath, outputPath, serverUri, verbose
     */
    public function __construct(array $config)
    {
        $this->config = $config;
        $this->performance = new PerformanceMonitor();
    }

    /**
     * Run the client application.
     *
     * @return int Exit code (0 for success, 1 for failure)
     */
    public function run(): int
    {
        try {
            Logger::setVerbose($this->config['verbose']);
            
            Logger::info('Audio Stream Client');
            Logger::info('Input: ' . $this->config['inputPath']);
            Logger::info('Output: ' . $this->config['outputPath']);
            Logger::info('Server: ' . $this->config['serverUri']);

            // Initialize performance monitor
            $fileSize = FileManager::getFileSize($this->config['inputPath']);
            $this->performance->setFileSize($fileSize);

            // Connect to WebSocket server
            $ws = new WebSocketClient($this->config['serverUri']);
            $ws->connect();
            
            // Upload file
            $this->performance->startUpload();
            $streamId = UploadManager::upload($ws, $this->config['inputPath']);
            $this->performance->endUpload();
            
            // Sleep 2 seconds after upload
            Logger::info('Upload successful, sleeping for 2 seconds...');
            usleep(2000000); // 2 seconds in microseconds
            
            // Download file
            $this->performance->startDownload();
            DownloadManager::download($ws, $streamId, $this->config['outputPath'], $fileSize);
            $this->performance->endDownload();
            
            // Sleep 2 seconds after download
            Logger::info('Download successful, sleeping for 2 seconds...');
            usleep(2000000); // 2 seconds in microseconds
            
            // Verify integrity
            $verification = VerificationModule::verify($this->config['inputPath'], $this->config['outputPath']);
            
            // Report performance
            $report = $this->performance->getReport();
            $this->performance->printReport($report);
            
            // Close connection
            $ws->close();
            
            // Exit with appropriate code
            if ($verification['passed']) {
                Logger::info('SUCCESS: File transfer completed successfully');
                return 0;
            } else {
                Logger::error('FAILURE: File verification failed');
                return 1;
            }

        } catch (\Exception $e) {
            Logger::error('Fatal error: ' . $e->getMessage());
            return 1;
        }
    }
}
