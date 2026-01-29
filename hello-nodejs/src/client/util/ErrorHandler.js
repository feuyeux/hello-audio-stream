/**
 * Centralized error handling for the audio stream client.
 * Provides consistent error handling, logging, and recovery strategies.
 * Matches the Java ErrorHandler interface.
 */

export class ErrorHandler {
  static DEFAULT_PREFIX = "stream";

  constructor() {
    this.errorCounts = {
      CONNECTION_ERROR: 0,
      FILE_IO_ERROR: 0,
      PROTOCOL_ERROR: 0,
      TIMEOUT_ERROR: 0,
      VALIDATION_ERROR: 0,
    };

    this.onErrorCallback = null;
  }

  // Error reporting

  /**
   * Report an error.
   *
   * @param {string} type - error type
   * @param {string} message - error message
   * @param {string} context - additional context
   * @param {boolean} recoverable - whether the error is recoverable
   */
  reportError(type, message, context = "", recoverable = false) {
    const timestamp = Date.now();
    const errorInfo = { type, message, context, timestamp, recoverable };

    // Increment error count
    this.incrementErrorCount(type);

    // Log the error
    const logMessage = `[${this.errorTypeToString(type)}] ${message} - Context: ${context}`;

    if (recoverable) {
      console.warn(logMessage);
    } else {
      console.error(logMessage);
    }

    // Call callback if set
    if (this.onErrorCallback) {
      this.onErrorCallback(errorInfo);
    }
  }

  // Error handling strategies

  /**
   * Handle connection error with retry logic.
   *
   * @param {string} message - error message
   * @param {number} retryCount - current retry count (will be incremented)
   * @param {number} maxRetries - maximum number of retries
   * @returns {boolean} true if should retry, false otherwise
   */
  handleConnectionError(message, retryCount, maxRetries) {
    this.reportError(
      "CONNECTION_ERROR",
      message,
      `Retry ${retryCount}/${maxRetries}`,
      retryCount < maxRetries,
    );

    return retryCount < maxRetries;
  }

  /**
   * Handle file I/O error.
   *
   * @param {string} message - error message
   * @param {string} filePath - file path that caused the error
   * @returns {boolean} false (file I/O errors are not recoverable)
   */
  handleFileIOError(message, filePath) {
    this.reportError("FILE_IO_ERROR", message, `File: ${filePath}`, false);
    return false;
  }

  /**
   * Handle protocol error.
   *
   * @param {string} message - error message
   * @param {string} expectedFormat - expected format description
   * @returns {boolean} false (protocol errors are not recoverable)
   */
  handleProtocolError(message, expectedFormat = "") {
    const context = expectedFormat ? `Expected: ${expectedFormat}` : "";
    this.reportError("PROTOCOL_ERROR", message, context, false);
    return false;
  }

  /**
   * Handle timeout error.
   *
   * @param {string} message - error message
   * @param {number} timeoutMs - timeout value in milliseconds
   * @returns {boolean} false (timeout errors are not recoverable by default)
   */
  handleTimeoutError(message, timeoutMs) {
    this.reportError(
      "TIMEOUT_ERROR",
      message,
      `Timeout: ${timeoutMs} ms`,
      false,
    );
    return false;
  }

  // Recovery strategies

  /**
   * Determine if an error should be retried.
   *
   * @param {string} type - error type
   * @param {number} currentAttempt - current attempt number
   * @param {number} maxAttempts - maximum number of attempts
   * @returns {boolean} true if should retry
   */
  shouldRetry(type, currentAttempt, maxAttempts) {
    if (currentAttempt >= maxAttempts) {
      return false;
    }

    // Only connection and timeout errors are retryable
    return type === "CONNECTION_ERROR" || type === "TIMEOUT_ERROR";
  }

  /**
   * Get retry delay in milliseconds using exponential backoff.
   *
   * @param {number} attempt - attempt number (1-based)
   * @returns {number} delay in milliseconds
   */
  getRetryDelayMs(attempt) {
    // Exponential backoff: 2^(attempt-1) * 1000 ms
    // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
    return Math.floor(Math.pow(2, attempt - 1) * 1000);
  }

  // Callbacks

  /**
   * Set callback for error events.
   *
   * @param {Function} callback - callback function
   */
  setOnError(callback) {
    this.onErrorCallback = callback;
  }

  // Statistics

  /**
   * Get error count for a specific type.
   *
   * @param {string} type - error type
   * @returns {number} error count
   */
  getErrorCount(type) {
    return this.errorCounts[type] || 0;
  }

  /**
   * Get total error count across all types.
   *
   * @returns {number} total error count
   */
  getTotalErrorCount() {
    return Object.values(this.errorCounts).reduce(
      (sum, count) => sum + count,
      0,
    );
  }

  /**
   * Clear all error counts.
   */
  clearErrorCounts() {
    for (const type in this.errorCounts) {
      this.errorCounts[type] = 0;
    }
    console.debug("Cleared all error counts");
  }

  // Private helper methods

  /**
   * Increment error count for a specific type.
   *
   * @param {string} type - error type
   */
  incrementErrorCount(type) {
    if (this.errorCounts.hasOwnProperty(type)) {
      this.errorCounts[type]++;
    }
  }

  /**
   * Convert error type to string.
   *
   * @param {string} type - error type
   * @returns {string} string representation
   */
  errorTypeToString(type) {
    return type;
  }
}
