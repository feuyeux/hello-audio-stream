package org.feuyeux.mmap.audio.client.core;

import org.feuyeux.mmap.audio.client.util.ErrorHandler;
import org.feuyeux.mmap.audio.client.util.PerformanceMonitor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
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
    private static final int CHUNK_SIZE = 65536; // 64KB

    private final WebSocketClient client;
    private final ErrorHandler errorHandler;
    private final PerformanceMonitor performanceMonitor;

    private BiConsumer<Long, Long> progressCallback;

    private int uploadDelayMs;

    /**
     * Create an upload manager.
     *
     * @param client       WebSocket client
     * @param errorHandler error handler (optional)
     */
    public UploadManager(WebSocketClient client, ErrorHandler errorHandler) {
        this(client, errorHandler, new PerformanceMonitor());
    }

    /**
     * Create an upload manager with all dependencies.
     *
     * @param client             WebSocket client
     * @param errorHandler       error handler
     * @param performanceMonitor performance monitor
     */
    public UploadManager(WebSocketClient client, ErrorHandler errorHandler,
                         PerformanceMonitor performanceMonitor) {
        this.client = client;
        this.errorHandler = errorHandler;
        this.performanceMonitor = performanceMonitor;
        this.uploadDelayMs = DEFAULT_UPLOAD_DELAY_MS;
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
            String streamId = generateStreamId();

            logger.info("Starting upload - File: {}, Size: {} bytes, StreamId: {}",
                    filePath.getFileName(), fileSize, streamId);

            performanceMonitor.startUpload();

            // Consume CONNECTED message if present
            try {
                String connectedMsg = client.waitForTextMessage(1000);
                if (connectedMsg != null && (connectedMsg.contains("\"type\":\"CONNECTED\"") || connectedMsg.contains("\"type\":\"connected\""))) {
                    logger.debug("Consumed CONNECTED message");
                }
            } catch (Exception e) {
                // Ignore if no CONNECTED message
            }

            // Send START message
            if (!sendStartMessage(streamId)) {
                return "";
            }

            TimeUnit.MILLISECONDS.sleep(MESSAGE_PAUSE_MS);

            // Send file chunks
            if (!sendFileChunks(filePath, fileSize)) {
                return "";
            }

            TimeUnit.MILLISECONDS.sleep(MESSAGE_PAUSE_MS);

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
            int chunkLength = Math.min(CHUNK_SIZE, fileData.length - offset);
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
                TimeUnit.MILLISECONDS.sleep(uploadDelayMs);
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
     * Generate a short stream ID.
     *
     * @return stream ID in format "stream-{short-uuid}"
     */
    private static String generateStreamId() {
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        String streamId = "stream-" + uuid;
        logger.debug("Generated stream ID: {}", streamId);
        return streamId;
    }
}
