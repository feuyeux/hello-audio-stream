package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Centralized error handling for the audio stream client.
 * Provides consistent error handling, logging, and recovery strategies.
 * Matches the C++ ErrorHandler interface.
 */
public class ErrorHandler {
    private static final Logger logger = LoggerFactory.getLogger(ErrorHandler.class);

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
     * Report an error.
     *
     * @param type        error type
     * @param message     error message
     * @param context     additional context
     * @param recoverable whether the error is recoverable
     */
    public void reportError(ErrorType type, String message, String context, boolean recoverable) {
        String logMessage = String.format("[%s] %s - Context: %s", type.name(), message, context);

        if (recoverable) {
            logger.warn(logMessage);
        } else {
            logger.error(logMessage);
        }
    }

    /**
     * Report an error without context.
     *
     * @param type    error type
     * @param message error message
     */
    public void reportError(ErrorType type, String message) {
        reportError(type, message, "", false);
    }
}
