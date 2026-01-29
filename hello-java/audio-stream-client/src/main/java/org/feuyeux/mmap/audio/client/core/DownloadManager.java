package org.feuyeux.mmap.audio.client.core;

import org.feuyeux.mmap.audio.client.util.ErrorHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Download manager for orchestrating file downloads from the server.
 * Handles GET request sequencing, binary frame assembly, and file writing.
 * Matches the C++ DownloadManager interface.
 */
public class DownloadManager {
    private static final Logger logger = LoggerFactory.getLogger(DownloadManager.class);
    private static final int MAX_RETRIES = 3;

    private final WebSocketClient client;
    private final FileManager fileManager;
    private final ChunkManager chunkManager;
    private final ErrorHandler errorHandler;

    private String lastError;
    private long bytesDownloaded;
    private long totalSize;
    private int requestTimeoutMs;
    private int maxRetries;

    /**
     * Create a download manager.
     *
     * @param client WebSocket client
     * @param fileManager file manager
     * @param chunkManager chunk manager
     * @param errorHandler error handler (optional)
     */
    public DownloadManager(WebSocketClient client, FileManager fileManager,
                           ChunkManager chunkManager, ErrorHandler errorHandler) {
        this.client = client;
        this.fileManager = fileManager;
        this.chunkManager = chunkManager;
        this.errorHandler = errorHandler;
        this.lastError = "";
        this.bytesDownloaded = 0;
        this.totalSize = 0;
        this.requestTimeoutMs = 5000;
        this.maxRetries = MAX_RETRIES;
    }

    /**
     * Download a file from the server.
     *
     * @param streamId stream identifier to download from
     * @param outputPath path to write the downloaded file
     * @return true if download was successful
     */
    public boolean downloadFile(String streamId, String outputPath) {
        return downloadFile(streamId, Path.of(outputPath), 0);
    }

    /**
     * Download a file from the server.
     *
     * @param streamId stream identifier to download from
     * @param outputPath path to write the downloaded file
     * @param expectedSize expected size of the file (0 if unknown)
     * @return true if download was successful
     */
    public boolean downloadFile(String streamId, Path outputPath, long expectedSize) {
        logger.info("Starting download - StreamId: {}, Output: {}", streamId, outputPath);

        this.bytesDownloaded = 0;
        this.totalSize = expectedSize;
        this.lastError = "";

        try {
            // Create output directory if needed
            Path parentDir = outputPath.getParent();
            if (parentDir != null && !Files.exists(parentDir)) {
                Files.createDirectories(parentDir);
                logger.debug("Created output directory: {}", parentDir);
            }

            List<byte[]> downloadedChunks = new ArrayList<>();
            long offset = 0;
            boolean hasMoreData = true;

            while (hasMoreData) {
                int retries = 0;
                byte[] chunkData = null;

                while (retries < maxRetries && chunkData == null) {
                    client.clearMessages();
                    
                    if (!sendGetRequest(streamId, offset, chunkManager.getChunkSize())) {
                        return handleProtocolError("Failed to send GET request", streamId);
                    }

                    chunkData = client.waitForBinaryMessage(requestTimeoutMs);

                    if (chunkData == null) {
                        if (isNoDataError()) {
                            // Server explicitly said no data available - download complete
                            logger.info("Download completed at offset: {} (no more data available)", offset);
                            hasMoreData = false;
                            break;
                        }
                        retries++;
                        if (retries < maxRetries) {
                            logger.warn("No data received at offset: {}, retry {}/{}", offset, retries, maxRetries);
                            Thread.sleep(100);
                        }
                    }
                }

                // If we broke out due to no more data, exit the loop
                if (!hasMoreData) {
                    break;
                }

                if (chunkData == null) {
                    // Failed after all retries
                    String errorMsg = String.format("Download failed at offset: %d after %d retries", offset, maxRetries);
                    if (errorHandler != null) {
                        errorHandler.reportError(ErrorHandler.ErrorType.TIMEOUT_ERROR,
                                errorMsg, streamId, false);
                    }
                    logger.error(errorMsg);
                    return false;
                }

                if (chunkData != null) {
                    downloadedChunks.add(chunkData);
                    bytesDownloaded += chunkData.length;
                    offset += chunkData.length;

                    if (downloadedChunks.size() % 100 == 0) {
                        logger.info("Download progress: {} bytes, {} chunks", bytesDownloaded, downloadedChunks.size());
                    }
                    
                    // Check if we received less data than requested - indicates end of file
                    if (chunkData.length < chunkManager.getChunkSize()) {
                        logger.info("Download completed at offset: {} (received partial chunk)", offset);
                        hasMoreData = false;
                    }
                }
            }

            // Write all chunks to file
            if (!fileManager.openForWriting(outputPath)) {
                return handleProtocolError("Failed to open output file for writing", outputPath.toString());
            }

            for (byte[] chunk : downloadedChunks) {
                if (!fileManager.write(chunk)) {
                    fileManager.closeWriter();
                    return handleProtocolError("Failed to write chunk to file", outputPath.toString());
                }
            }

            fileManager.closeWriter();

            logger.info("Download completed - Total chunks: {}, Total bytes: {}",
                    downloadedChunks.size(), bytesDownloaded);
            return true;

        } catch (IOException e) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.FILE_IO_ERROR,
                        "I/O error during download: " + e.getMessage(), streamId, false);
            }
            logger.error("Download failed for stream: {}", streamId, e);
            lastError = "I/O error: " + e.getMessage();
            return false;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR,
                        "Download interrupted", streamId, false);
            }
            logger.error("Download interrupted for stream: {}", streamId, e);
            lastError = "Download interrupted";
            return false;
        }
    }

    /**
     * Get the last error message.
     *
     * @return error message string
     */
    public String getLastError() {
        return lastError;
    }

    /**
     * Get download progress (0.0 to 1.0).
     *
     * @return progress as a fraction
     */
    public double getProgress() {
        if (totalSize <= 0) {
            return 0.0;
        }
        return (double) bytesDownloaded / totalSize;
    }

    /**
     * Get total bytes downloaded.
     *
     * @return number of bytes downloaded
     */
    public long getBytesDownloaded() {
        return bytesDownloaded;
    }

    /**
     * Set timeout for GET requests.
     *
     * @param timeoutMs timeout in milliseconds
     */
    public void setRequestTimeout(int timeoutMs) {
        this.requestTimeoutMs = timeoutMs;
    }

    /**
     * Set maximum retry attempts for failed requests.
     *
     * @param maxRetries maximum number of retry attempts
     */
    public void setMaxRetries(int maxRetries) {
        this.maxRetries = maxRetries;
    }

    /**
     * Handle server response message (called from main message router).
     *
     * @param message server response message
     */
    public void handleServerResponse(String message) {
        logger.debug("Received server response during download: {}", message);
        // Handle responses if needed
    }

    // Private helper methods

    /**
     * Send a GET request for a specific chunk.
     *
     * @param streamId stream identifier
     * @param offset byte offset to request
     * @param length number of bytes to request
     * @return true if request was sent successfully
     */
    private boolean sendGetRequest(String streamId, long offset, int length) {
        try {
            String message = String.format("{\"type\":\"GET\",\"streamId\":\"%s\",\"offset\":%d,\"length\":%d}",
                    streamId, offset, length);
            client.sendTextMessage(message);
            logger.debug("Sent GET request - stream: {}, offset: {}, length: {}", streamId, offset, length);
            return true;
        } catch (Exception e) {
            if (errorHandler != null) {
                errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR,
                        "Failed to send GET request: " + e.getMessage(),
                        String.format("stream=%s, offset=%d", streamId, offset), false);
            }
            logger.error("Failed to send GET request", e);
            return false;
        }
    }

    /**
     * Check if the last message was an error message indicating no data available.
     *
     * @return true if last error message indicates no data available
     */
    private boolean isNoDataError() {
        // Check if the last text message indicates no data
        String lastMessage = client.waitForTextMessage(0);
        return lastMessage != null && lastMessage.contains("No data available");
    }

    /**
     * Handle protocol errors with proper error reporting.
     *
     * @param message error message
     * @param context error context
     * @return false (always fails)
     */
    private boolean handleProtocolError(String message, String context) {
        if (errorHandler != null) {
            errorHandler.reportError(ErrorHandler.ErrorType.PROTOCOL_ERROR, message, context, false);
        }
        logger.error("{} - Context: {}", message, context);
        lastError = message;
        return false;
    }
}
