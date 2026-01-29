package org.feuyeux.mmap.audio.client;

import org.feuyeux.mmap.audio.client.core.*;
import org.feuyeux.mmap.audio.client.util.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Audio Stream Client Application.
 * Main entry point for audio streaming client application.
 * Performs upload, download, and file verification operations.
 *
 * <p>Uses a long-lived WebSocket connection that is established at startup
 * and maintained throughout the application lifecycle. The connection is closed
 * automatically via shutdown hook when the process exits.
 */
public class AudioClientApplication {
    private static final Logger logger = LoggerFactory.getLogger(AudioClientApplication.class);

    private static final String DEFAULT_SERVER_URI = "ws://localhost:8080/audio";
    private static final int DEFAULT_CHUNK_SIZE = 65536; // 64KB

    public static void main(String[] args) {
        String inputFilePath = args.length > 0 ? args[0] : null;
        // Validate input file
        if (inputFilePath == null) {
            logger.error("Input file not specified. Usage: java -jar audio-stream-client.jar [serverUri] [inputFile] [chunkSize]");
            System.exit(1);
        }

        Path inputFile = Path.of(inputFilePath);
        if (!Files.exists(inputFile)) {
            logger.error("Input file does not exist: {}", inputFile);
            System.exit(1);
        }

        try {
            // Generate output file path with timestamp
            Path outputFile = generateOutputPath(inputFile);
            
            // Ensure output directory exists
            Path outputDir = outputFile.getParent();
            if (outputDir != null && !Files.exists(outputDir)) {
                Files.createDirectories(outputDir);
                logger.info("Created output directory: {}", outputDir);
            }

            logger.info("\n=== Starting Audio Stream Test ===");
            logger.info("Input File: {}", inputFile);
            logger.info("Output File: {}", outputFile.getFileName());
            logger.info("================================\n");

            String streamId = new StreamIdGenerator().generateShort();

            long operationStartTime = System.currentTimeMillis();

            // Initialize components
            WebSocketClient wsClient = new WebSocketClient(URI.create(DEFAULT_SERVER_URI));
            FileManager fileManager = new FileManager();
            ChunkManager chunkManager = new ChunkManager();
            ErrorHandler errorHandler = new ErrorHandler();
            PerformanceMonitor performanceMonitor = new PerformanceMonitor();
            StreamIdGenerator streamIdGenerator = new StreamIdGenerator();
            
            UploadManager uploadManager = new UploadManager(
                wsClient, fileManager, chunkManager, errorHandler, performanceMonitor, streamIdGenerator
            );
            DownloadManager downloadManager = new DownloadManager(
                wsClient, fileManager, chunkManager, errorHandler
            );

            // Connect to server with retry
            if (!wsClient.connectWithRetry(10)) {
                logger.error("Failed to connect to server after retries");
                System.exit(1);
            }

            // 添加关闭钩子，确保进程退出时关闭连接（长连接）
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                logger.info("Shutdown hook: Closing WebSocket connection...");
                wsClient.close();
            }));

            String uploadStreamId;
            boolean downloadSuccess;
            VerificationModule.VerificationReport verificationResult;

            try {
                // 1. 上传音频
                logger.info("[1/3] Uploading file...");
                uploadStreamId = uploadManager.uploadFile(inputFile);
                
                if (uploadStreamId.isEmpty()) {
                    logger.error("Upload failed");
                    System.exit(1);
                }
                
                PerformanceMonitor.PerformanceMetrics uploadMetrics = performanceMonitor.getMetrics();
                logger.info("Upload result: streamId={}, duration={}ms, throughput={} Mbps", 
                    uploadStreamId, uploadMetrics.uploadDurationMs, 
                    String.format("%.2f", uploadMetrics.uploadThroughputMbps));

                // 2. 上传成功后sleep2秒
                logger.info("Upload successful, sleeping for 2 seconds...");
                Thread.sleep(2000);

                // 3. 下载音频
                logger.info("[2/3] Downloading file...");
                performanceMonitor.startDownload();
                downloadSuccess = downloadManager.downloadFile(uploadStreamId, outputFile, 0);
                
                if (!downloadSuccess) {
                    logger.error("Download failed: {}", downloadManager.getLastError());
                    System.exit(1);
                }
                
                long downloadedBytes = downloadManager.getBytesDownloaded();
                performanceMonitor.endDownload(downloadedBytes);
                
                PerformanceMonitor.PerformanceMetrics downloadMetrics = performanceMonitor.getMetrics();
                logger.info("Download result: success={}, duration={}ms, throughput={} Mbps", 
                    downloadSuccess, downloadMetrics.downloadDurationMs,
                    String.format("%.2f", downloadMetrics.downloadThroughputMbps));

                // 4. 下载成功后sleep2秒
                logger.info("Download successful, sleeping for 2 seconds...");
                Thread.sleep(2000);

                // 5. 比较上传和下载的音频
                logger.info("[3/3] Comparing files...");
                VerificationModule verificationModule = new VerificationModule();
                verificationResult = verificationModule.generateReport(inputFile, outputFile);
                verificationResult.printReport();

            } catch (Exception e) {
                logger.error("Application execution failed", e);
                throw e;
            }

            long operationEndTime = System.currentTimeMillis();
            long totalDurationMs = operationEndTime - operationStartTime;

            boolean isSuccess = verificationResult.isVerificationPassed();
            PerformanceMonitor.PerformanceMetrics metrics = performanceMonitor.getMetrics();
            
            String duration = String.format("Total Duration: %d ms (%.2f seconds)",
                    totalDurationMs, totalDurationMs / 1000.0);
            String upThroughput = String.format("Upload Throughput: %.2f Mbps", metrics.uploadThroughputMbps);
            String downThroughput = String.format("Download Throughput: %.2f Mbps", metrics.downloadThroughputMbps);
            
            logger.info("\n=== Operation Summary ===");
            logger.info("Stream ID: {}", uploadStreamId);
            logger.info(duration);
            logger.info("Upload Time: {} ms", metrics.uploadDurationMs);
            logger.info("Download Time: {} ms", metrics.downloadDurationMs);
            logger.info(upThroughput);
            logger.info(downThroughput);
            logger.info("Content Match: {}", isSuccess);
            logger.info("Overall Result: {}", isSuccess ? "SUCCESS" : "FAILED");
            logger.info("==========================\n");

            // 一致则返回成功，否则返回失败
            if (isSuccess) {
                logger.info("Audio stream test completed successfully!");
                System.exit(0);
            } else {
                logger.error("Audio stream test failed: Files do not match!");
                System.exit(1);
            }
        } catch (Exception e) {
            logger.error("Application execution failed", e);
            System.exit(1);
        }
    }

    /**
     * Generates an output file path based on input file name with timestamp.
     *
     * @param inputFile input file path
     * @return output file path
     */
    private static Path generateOutputPath(Path inputFile) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
        String originalName = inputFile.getFileName().toString();
        String outputName = "output-" + timestamp + "-" + originalName;
        
        // Use audio/output directory relative to current working directory
        Path outputDir = Path.of("audio", "output");
        return outputDir.resolve(outputName);
    }

}