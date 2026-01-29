package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;
import java.util.function.Consumer;

/**
 * Centralized error handling for the audio stream client.
 * Provides consistent error handling, logging, and recovery strategies.
 * Matches the C++ ErrorHandler interface.
 */
public class ErrorHandler {
    private static final Logger logger = LoggerFactory.getLogger(ErrorHandler.class);

    private final Map<ErrorType, Integer> errorCounts;
    private Consumer<ErrorInfo> onErrorCallback;

    public ErrorHandler() {
        this.errorCounts = new HashMap<>();
        for (ErrorType type : ErrorType.values()) {
            errorCounts.put(type, 0);
        }
    }

    /**
     * Error types enumeration.
     */
    public enum ErrorType {
        CONNECTION_ERROR,
        FILE_IO_ERROR,
        PROTOCOL_ERROR,
        TIMEOUT_ERROR,
        VALIDATION_ERROR
    }

    /**
     * Error information class.
     */
    public static class ErrorInfo {
        public final ErrorType type;
        public final String message;
        public final String context;
        public final long timestamp;
        public final boolean recoverable;

        public ErrorInfo(ErrorType type, String message, String context, long timestamp, boolean recoverable) {
            this.type = type;
            this.message = message;
            this.context = context;
            this.timestamp = timestamp;
            this.recoverable = recoverable;
        }

        @Override
        public String toString() {
            return String.format("ErrorInfo{type=%s, message='%s', context='%s', recoverable=%s}",
                    type, message, context, recoverable);
        }
    }

    // Error reporting

    /**
     * Report an error.
     *
     * @param type error type
     * @param message error message
     * @param context additional context
     * @param recoverable whether the error is recoverable
     */
    public void reportError(ErrorType type, String message, String context, boolean recoverable) {
        long timestamp = System.currentTimeMillis();
        ErrorInfo errorInfo = new ErrorInfo(type, message, context, timestamp, recoverable);
        
        // Increment error count
        incrementErrorCount(type);
        
        // Log the error
        String logMessage = String.format("[%s] %s - Context: %s", 
                errorTypeToString(type), message, context);
        
        if (recoverable) {
            logger.warn(logMessage);
        } else {
            logger.error(logMessage);
        }
        
        // Call callback if set
        if (onErrorCallback != null) {
            onErrorCallback.accept(errorInfo);
        }
    }

    /**
     * Report an error without context.
     *
     * @param type error type
     * @param message error message
     */
    public void reportError(ErrorType type, String message) {
        reportError(type, message, "", false);
    }

    // Error handling strategies

    /**
     * Handle connection error with retry logic.
     *
     * @param message error message
     * @param retryCount current retry count (will be incremented)
     * @param maxRetries maximum number of retries
     * @return true if should retry, false otherwise
     */
    public boolean handleConnectionError(String message, int retryCount, int maxRetries) {
        reportError(ErrorType.CONNECTION_ERROR, message, 
                String.format("Retry %d/%d", retryCount, maxRetries), retryCount < maxRetries);
        
        return retryCount < maxRetries;
    }

    /**
     * Handle file I/O error.
     *
     * @param message error message
     * @param filePath file path that caused the error
     * @return false (file I/O errors are not recoverable)
     */
    public boolean handleFileIOError(String message, String filePath) {
        reportError(ErrorType.FILE_IO_ERROR, message, "File: " + filePath, false);
        return false;
    }

    /**
     * Handle protocol error.
     *
     * @param message error message
     * @param expectedFormat expected format description
     * @return false (protocol errors are not recoverable)
     */
    public boolean handleProtocolError(String message, String expectedFormat) {
        String context = expectedFormat.isEmpty() ? "" : "Expected: " + expectedFormat;
        reportError(ErrorType.PROTOCOL_ERROR, message, context, false);
        return false;
    }

    /**
     * Handle timeout error.
     *
     * @param message error message
     * @param timeoutMs timeout value in milliseconds
     * @return false (timeout errors are not recoverable by default)
     */
    public boolean handleTimeoutError(String message, int timeoutMs) {
        reportError(ErrorType.TIMEOUT_ERROR, message, 
                String.format("Timeout: %d ms", timeoutMs), false);
        return false;
    }

    // Recovery strategies

    /**
     * Determine if an error should be retried.
     *
     * @param type error type
     * @param currentAttempt current attempt number
     * @param maxAttempts maximum number of attempts
     * @return true if should retry
     */
    public boolean shouldRetry(ErrorType type, int currentAttempt, int maxAttempts) {
        if (currentAttempt >= maxAttempts) {
            return false;
        }
        
        // Only connection and timeout errors are retryable
        return type == ErrorType.CONNECTION_ERROR || type == ErrorType.TIMEOUT_ERROR;
    }

    /**
     * Get retry delay in milliseconds using exponential backoff.
     *
     * @param attempt attempt number (1-based)
     * @return delay in milliseconds
     */
    public int getRetryDelayMs(int attempt) {
        // Exponential backoff: 2^(attempt-1) * 1000 ms
        // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
        return (int) (Math.pow(2, attempt - 1) * 1000);
    }

    // Callbacks

    /**
     * Set callback for error events.
     *
     * @param callback callback function
     */
    public void setOnError(Consumer<ErrorInfo> callback) {
        this.onErrorCallback = callback;
    }

    // Statistics

    /**
     * Get error count for a specific type.
     *
     * @param type error type
     * @return error count
     */
    public int getErrorCount(ErrorType type) {
        return errorCounts.getOrDefault(type, 0);
    }

    /**
     * Get total error count across all types.
     *
     * @return total error count
     */
    public int getTotalErrorCount() {
        return errorCounts.values().stream().mapToInt(Integer::intValue).sum();
    }

    /**
     * Clear all error counts.
     */
    public void clearErrorCounts() {
        for (ErrorType type : ErrorType.values()) {
            errorCounts.put(type, 0);
        }
        logger.debug("Cleared all error counts");
    }

    // Private helper methods

    /**
     * Increment error count for a specific type.
     *
     * @param type error type
     */
    private void incrementErrorCount(ErrorType type) {
        errorCounts.put(type, errorCounts.get(type) + 1);
    }

    /**
     * Convert error type to string.
     *
     * @param type error type
     * @return string representation
     */
    private String errorTypeToString(ErrorType type) {
        return switch (type) {
            case CONNECTION_ERROR -> "CONNECTION_ERROR";
            case FILE_IO_ERROR -> "FILE_IO_ERROR";
            case PROTOCOL_ERROR -> "PROTOCOL_ERROR";
            case TIMEOUT_ERROR -> "TIMEOUT_ERROR";
            case VALIDATION_ERROR -> "VALIDATION_ERROR";
        };
    }
}
