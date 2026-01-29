package org.feuyeux.mmap.audio.client.core;

import org.feuyeux.mmap.audio.client.util.ErrorHandler;
import org.feuyeux.mmap.audio.client.util.PerformanceMonitor;
import org.feuyeux.mmap.audio.client.util.StreamIdGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.function.BiConsumer;

/**
 * Upload manager for orchestrating file upload workflow.
 * Handles the complete upload process: START -> chunks -> STOP.
 * Matches the C++ UploadManager interface.
 */
public class UploadManager {
    private static final Logger logger = LoggerFactory.getLogger(UploadManager.class);
    private static final int MESSAGE_PAUSE_MS = 500;
    private static final int DEFAULT_UPLOAD_DELAY_MS = 10;

    private final WebSocketClient client;
    private final FileManager fileManager;
    private final ChunkManager chunkManager;
    private final ErrorHandler errorHandler;
    private final PerformanceMonitor performanceMonitor;
    private final StreamIdGenerator streamIdGenerator;

    private BiConsumer<Long, Long> progressCallback;
    private int responseTimeoutMs;
    private int uploadDelayMs;

    /**
     * Create an upload manager.
     *
     * @param client WebSocket client
     * @param errorHandler error handler (optional)
     */
    public UploadManager(WebSocketClient client, ErrorHandler errorHandler) {
        this(client, new FileManager(), new ChunkManager(), errorHandler,
                new PerformanceMonitor(), new StreamIdGenerator());
    }

    /**
     * Create an upload manager with all dependencies.
     *
     * @param client WebSocket client
     * @param fileManager file manager
     * @param chunkManager chunk manager
     * @param errorHandler error handler
     * @param performanceMonitor performance monitor
     * @param streamIdGenerator stream ID generator
     */
    public UploadManager(WebSocketClient client, FileManager fileManager, ChunkManager chunkManager,
                         ErrorHandler errorHandler, PerformanceMonitor performanceMonitor,
                         StreamIdGenerator streamIdGenerator) {
        this.client = client;
        this.fileManager = fileManager;
        this.chunkManager = chunkManager;
        this.errorHandler = errorHandler;
        this.performanceMonitor = performanceMonitor;
        this.streamIdGenerator = streamIdGenerator;
        this.responseTimeoutMs = 5000;
        this.uploadDelayMs = DEFAULT_UPLOAD_DELAY_MS;
    }

    /**
     * Upload a file to the server.
     *
     * @param filePath path to the file to upload
     * @return generated stream ID if successful, empty string if failed
     */
    public String uploadFile(String filePath) {
        return uploadFile(Path.of(filePath));
    }

    /**
     * Upload a file to the server.
     *
     * @param filePath path to the file to upload
     * @return generated stream ID if successful, empty string if failed
     */
    public String uploadFile(Path filePath) {
        if (!Files.exists(filePath)) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.FILE_IO_ERROR,
                        "File not found", filePath.toString(), false);
            }
            logger.error("File not found: {}", filePath);
            return "";
        }

        try {
            long fileSize = Files.size(filePath);
            String streamId = streamIdGenerator.generateShort();

            logger.info("Starting upload - File: {}, Size: {} bytes, StreamId: {}",
                    filePath.getFileName(), fileSize, streamId);

            performanceMonitor.startUpload();

            // Send START message
            if (!sendStartMessage(streamId)) {
                return "";
            }

            Thread.sleep(MESSAGE_PAUSE_MS);

            // Send file chunks
            if (!sendFileChunks(filePath, fileSize)) {
                return "";
            }

            Thread.sleep(MESSAGE_PAUSE_MS);

            // Send STOP message
            if (!sendStopMessage(streamId)) {
                return "";
            }

            performanceMonitor.endUpload(fileSize);

            logger.info("Upload completed successfully with stream ID: {}", streamId);
            return streamId;

        } catch (IOException e) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.FILE_IO_ERROR,
                        "Failed to read file: " + e.getMessage(), filePath.toString(), false);
            }
            logger.error("Upload failed for file: {}", filePath, e);
            return "";
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR,
                        "Upload interrupted", filePath.toString(), false);
            }
            logger.error("Upload interrupted for file: {}", filePath, e);
            return "";
        }
    }

    /**
     * Set callback for upload progress.
     *
     * @param callback function called with (bytesUploaded, totalBytes)
     */
    public void setProgressCallback(BiConsumer<Long, Long> callback) {
        this.progressCallback = callback;
    }

    /**
     * Get performance metrics from last upload.
     *
     * @return performance metrics
     */
    public PerformanceMonitor.PerformanceMetrics getPerformanceMetrics() {
        return performanceMonitor.getMetrics();
    }

    /**
     * Set timeout for server responses.
     *
     * @param timeoutMs timeout in milliseconds
     */
    public void setResponseTimeout(int timeoutMs) {
        this.responseTimeoutMs = timeoutMs;
    }

    /**
     * Set delay between chunk uploads.
     *
     * @param delayMs delay in milliseconds
     */
    public void setUploadDelay(int delayMs) {
        this.uploadDelayMs = delayMs;
    }

    /**
     * Handle server response message (called from main message router).
     *
     * @param message server response message
     */
    public void handleServerResponse(String message) {
        logger.debug("Received server response during upload: {}", message);
        // Handle acknowledgments if needed
    }

    // Private helper methods

    /**
     * Send START message to begin streaming.
     *
     * @param streamId stream identifier
     * @return true if successful
     */
    private boolean sendStartMessage(String streamId) {
        try {
            String message = String.format("{\"type\":\"START\",\"streamId\":\"%s\"}", streamId);
            client.sendTextMessage(message);
            logger.info("Sent START message for stream: {}", streamId);
            return true;
        } catch (Exception e) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR,
                        "Failed to send START message: " + e.getMessage(), streamId, false);
            }
            logger.error("Failed to send START message", e);
            return false;
        }
    }

    /**
     * Send file chunks to the server.
     *
     * @param filePath path to the file
     * @param fileSize size of the file
     * @return true if successful
     */
    private boolean sendFileChunks(Path filePath, long fileSize) throws IOException, InterruptedException {
        byte[] fileData = Files.readAllBytes(filePath);
        int offset = 0;
        int totalChunks = 0;
        long totalBytesTransferred = 0;

        while (offset < fileData.length) {
            int chunkLength = Math.min(chunkManager.getChunkSize(), fileData.length - offset);
            byte[] chunk = new byte[chunkLength];
            System.arraycopy(fileData, offset, chunk, 0, chunkLength);

            client.sendBinaryMessage(chunk);
            totalBytesTransferred += chunkLength;
            totalChunks++;

            // Call progress callback if set
            if (progressCallback != null) {
                progressCallback.accept(totalBytesTransferred, fileSize);
            }

            if (uploadDelayMs > 0) {
                Thread.sleep(uploadDelayMs);
            }

            offset += chunkLength;

            if (totalChunks % 100 == 0) {
                logger.info("Upload progress: {} / {} bytes ({}%)",
                        totalBytesTransferred, fileSize,
                        String.format("%.1f", totalBytesTransferred * 100.0 / fileSize));
            }
        }

        logger.info("Sent {} chunks ({} bytes)", totalChunks, totalBytesTransferred);
        return true;
    }

    /**
     * Send STOP message to end streaming.
     *
     * @param streamId stream identifier
     * @return true if successful
     */
    private boolean sendStopMessage(String streamId) {
        try {
            String message = "{\"type\":\"STOP\"}";
            client.sendTextMessage(message);
            logger.info("Sent STOP message");
            return true;
        } catch (Exception e) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR,
                        "Failed to send STOP message: " + e.getMessage(), streamId, false);
            }
            logger.error("Failed to send STOP message", e);
            return false;
        }
    }

    /**
     * Wait for server response with timeout.
     *
     * @param expectedType expected message type
     * @param timeoutMs timeout in milliseconds
     */
    private void waitForResponse(String expectedType, int timeoutMs) {
        // Implementation for waiting for specific response type
        // This can be enhanced based on protocol requirements
        try {
            String response = client.waitForTextMessage(timeoutMs);
            if (response != null) {
                logger.debug("Received response: {}", response);
            }
        } catch (Exception e) {
            logger.warn("Timeout waiting for response: {}", expectedType);
        }
    }
}
