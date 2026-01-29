package client.util

import Logger

/**
 * Error handling utilities
 */
object ErrorHandler {
    /**
     * Handle an error with logging and optional recovery
     */
    fun handleError(message: String, exception: Exception? = null): Nothing {
        Logger.error(message)
        if (exception != null) {
            Logger.error("Exception: ${exception.message}")
            exception.printStackTrace()
        }
        throw exception ?: Exception(message)
    }
    
    /**
     * Log a warning without throwing
     */
    fun logWarning(message: String) {
        Logger.warn(message)
    }
    
    /**
     * Wrap a block with error handling
     */
    inline fun <T> withErrorHandling(operation: String, block: () -> T): T {
        return try {
            block()
        } catch (e: Exception) {
            handleError("Error during $operation", e)
        }
    }
}
