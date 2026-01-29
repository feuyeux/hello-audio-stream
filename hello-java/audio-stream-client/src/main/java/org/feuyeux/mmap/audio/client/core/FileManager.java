package org.feuyeux.mmap.audio.client.core;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * File manager for reading and writing audio files.
 * Handles file I/O operations with proper resource management.
 * Matches the C++ FileManager interface.
 */
public class FileManager implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(FileManager.class);
    private static final int DEFAULT_CHUNK_SIZE = 65536; // 64KB

    private String filePath;
    private long fileSize;
    private InputStream inputStream;
    private OutputStream outputStream;
    private long bytesRead;

    public FileManager() {
        this.fileSize = 0;
        this.bytesRead = 0;
    }

    // File reading methods

    /**
     * Open a file for reading.
     *
     * @param filePath path to the file
     * @return true if file opened successfully
     */
    public boolean openForReading(String filePath) {
        return openForReading(Path.of(filePath));
    }

    /**
     * Open a file for reading.
     *
     * @param filePath path to the file
     * @return true if file opened successfully
     */
    public boolean openForReading(Path filePath) {
        try {
            if (!Files.exists(filePath)) {
                logger.error("File does not exist: {}", filePath);
                return false;
            }

            this.filePath = filePath.toString();
            this.fileSize = Files.size(filePath);
            this.inputStream = new BufferedInputStream(Files.newInputStream(filePath));
            this.bytesRead = 0;

            logger.debug("Opened file for reading: {} ({} bytes)", filePath, fileSize);
            return true;
        } catch (IOException e) {
            logger.error("Failed to open file for reading: {}", filePath, e);
            return false;
        }
    }

    /**
     * Read data from the file.
     *
     * @param buffer buffer to read into
     * @param size maximum number of bytes to read
     * @return number of bytes actually read, or -1 if end of file
     */
    public int read(byte[] buffer, int size) {
        if (inputStream == null) {
            logger.error("No file open for reading");
            return -1;
        }

        try {
            int bytesToRead = Math.min(size, buffer.length);
            int bytesReadNow = inputStream.read(buffer, 0, bytesToRead);
            
            if (bytesReadNow > 0) {
                bytesRead += bytesReadNow;
            }
            
            return bytesReadNow;
        } catch (IOException e) {
            logger.error("Failed to read from file", e);
            return -1;
        }
    }

    /**
     * Read next chunk from the file (64KB).
     *
     * @return byte array containing the chunk, or null if end of file or error
     */
    public byte[] readChunk() {
        if (inputStream == null) {
            logger.error("No file open for reading");
            return null;
        }

        try {
            byte[] buffer = new byte[DEFAULT_CHUNK_SIZE];
            int bytesReadNow = inputStream.read(buffer);
            
            if (bytesReadNow <= 0) {
                return null; // End of file
            }
            
            bytesRead += bytesReadNow;
            
            // If we read less than the buffer size, return a smaller array
            if (bytesReadNow < buffer.length) {
                byte[] result = new byte[bytesReadNow];
                System.arraycopy(buffer, 0, result, 0, bytesReadNow);
                return result;
            }
            
            return buffer;
        } catch (IOException e) {
            logger.error("Failed to read chunk from file", e);
            return null;
        }
    }

    /**
     * Check if there is more data to read.
     *
     * @return true if more data available, false otherwise
     */
    public boolean hasMoreData() {
        if (inputStream == null) {
            return false;
        }

        try {
            return inputStream.available() > 0 || bytesRead < fileSize;
        } catch (IOException e) {
            logger.error("Failed to check available data", e);
            return false;
        }
    }

    /**
     * Get the size of the currently open file.
     *
     * @return file size in bytes
     */
    public long getFileSize() {
        return fileSize;
    }

    /**
     * Close the input stream.
     */
    public void closeReader() {
        if (inputStream != null) {
            try {
                inputStream.close();
                logger.debug("Closed input stream for: {}", filePath);
            } catch (IOException e) {
                logger.error("Failed to close input stream", e);
            } finally {
                inputStream = null;
            }
        }
    }

    // File writing methods

    /**
     * Open a file for writing.
     *
     * @param filePath path to the file
     * @return true if file opened successfully
     */
    public boolean openForWriting(String filePath) {
        return openForWriting(Path.of(filePath));
    }

    /**
     * Open a file for writing.
     *
     * @param filePath path to the file
     * @return true if file opened successfully
     */
    public boolean openForWriting(Path filePath) {
        try {
            // Create parent directories if they don't exist
            Path parentDir = filePath.getParent();
            if (parentDir != null && !Files.exists(parentDir)) {
                Files.createDirectories(parentDir);
                logger.debug("Created directory: {}", parentDir);
            }

            this.filePath = filePath.toString();
            this.outputStream = new BufferedOutputStream(Files.newOutputStream(filePath));

            logger.debug("Opened file for writing: {}", filePath);
            return true;
        } catch (IOException e) {
            logger.error("Failed to open file for writing: {}", filePath, e);
            return false;
        }
    }

    /**
     * Write data to the file.
     *
     * @param data data to write
     * @return true if write successful
     */
    public boolean write(byte[] data) {
        if (outputStream == null) {
            logger.error("No file open for writing");
            return false;
        }

        try {
            outputStream.write(data);
            return true;
        } catch (IOException e) {
            logger.error("Failed to write to file", e);
            return false;
        }
    }

    /**
     * Close the output stream.
     */
    public void closeWriter() {
        if (outputStream != null) {
            try {
                outputStream.flush();
                outputStream.close();
                logger.debug("Closed output stream for: {}", filePath);
            } catch (IOException e) {
                logger.error("Failed to close output stream", e);
            } finally {
                outputStream = null;
            }
        }
    }

    // Utility methods

    /**
     * Check if a file exists.
     *
     * @param filePath path to the file
     * @return true if file exists
     */
    public boolean fileExists(String filePath) {
        return Files.exists(Path.of(filePath));
    }

    /**
     * Get the path of the currently open file.
     *
     * @return file path
     */
    public String getFilePath() {
        return filePath;
    }

    /**
     * Close all open streams.
     */
    @Override
    public void close() {
        closeReader();
        closeWriter();
    }
}
