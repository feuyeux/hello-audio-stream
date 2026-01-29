/**
 * Centralized error handling for the audio stream client.
 * Provides consistent error handling, logging, and recovery strategies.
 * Matches the Java ErrorHandler interface.
 */

export enum ErrorType {
  CONNECTION_ERROR = "CONNECTION_ERROR",
  FILE_IO_ERROR = "FILE_IO_ERROR",
  PROTOCOL_ERROR = "PROTOCOL_ERROR",
  TIMEOUT_ERROR = "TIMEOUT_ERROR",
  VALIDATION_ERROR = "VALIDATION_ERROR",
}

export interface ErrorInfo {
  type: ErrorType;
  message: string;
  context: string;
  timestamp: number;
  recoverable: boolean;
}

export class ErrorHandler {
  private errorCounts: Record<ErrorType, number>;
  private onErrorCallback?: (errorInfo: ErrorInfo) => void;

  constructor() {
    this.errorCounts = {
      [ErrorType.CONNECTION_ERROR]: 0,
      [ErrorType.FILE_IO_ERROR]: 0,
      [ErrorType.PROTOCOL_ERROR]: 0,
      [ErrorType.TIMEOUT_ERROR]: 0,
      [ErrorType.VALIDATION_ERROR]: 0,
    };

    this.onErrorCallback = undefined;
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
  reportError(
    type: ErrorType,
    message: string,
    context: string = "",
    recoverable: boolean = false,
  ): void {
    const timestamp = Date.now();
    const errorInfo: ErrorInfo = {
      type,
      message,
      context,
      timestamp,
      recoverable,
    };

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
   * @param message error message
   * @param retryCount current retry count (will be incremented)
   * @param maxRetries maximum number of retries
   * @returns true if should retry, false otherwise
   */
  handleConnectionError(
    message: string,
    retryCount: number,
    maxRetries: number,
  ): boolean {
    this.reportError(
      ErrorType.CONNECTION_ERROR,
      message,
      `Retry ${retryCount}/${maxRetries}`,
      retryCount < maxRetries,
    );

    return retryCount < maxRetries;
  }

  /**
   * Handle file I/O error.
   *
   * @param message error message
   * @param filePath file path that caused the error
   * @returns false (file I/O errors are not recoverable)
   */
  handleFileIOError(message: string, filePath: string): boolean {
    this.reportError(
      ErrorType.FILE_IO_ERROR,
      message,
      `File: ${filePath}`,
      false,
    );
    return false;
  }

  /**
   * Handle protocol error.
   *
   * @param message error message
   * @param expectedFormat expected format description
   * @returns false (protocol errors are not recoverable)
   */
  handleProtocolError(message: string, expectedFormat: string = ""): boolean {
    const context = expectedFormat ? `Expected: ${expectedFormat}` : "";
    this.reportError(ErrorType.PROTOCOL_ERROR, message, context, false);
    return false;
  }

  /**
   * Handle timeout error.
   *
   * @param message error message
   * @param timeoutMs timeout value in milliseconds
   * @returns false (timeout errors are not recoverable by default)
   */
  handleTimeoutError(message: string, timeoutMs: number): boolean {
    this.reportError(
      ErrorType.TIMEOUT_ERROR,
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
   * @param type error type
   * @param currentAttempt current attempt number
   * @param maxAttempts maximum number of attempts
   * @returns true if should retry
   */
  shouldRetry(
    type: ErrorType,
    currentAttempt: number,
    maxAttempts: number,
  ): boolean {
    if (currentAttempt >= maxAttempts) {
      return false;
    }

    // Only connection and timeout errors are retryable
    return (
      type === ErrorType.CONNECTION_ERROR || type === ErrorType.TIMEOUT_ERROR
    );
  }

  /**
   * Get retry delay in milliseconds using exponential backoff.
   *
   * @param attempt attempt number (1-based)
   * @returns delay in milliseconds
   */
  getRetryDelayMs(attempt: number): number {
    // Exponential backoff: 2^(attempt-1) * 1000 ms
    // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
    return Math.floor(Math.pow(2, attempt - 1) * 1000);
  }

  // Callbacks

  /**
   * Set callback for error events.
   *
   * @param callback callback function
   */
  setOnError(callback: (errorInfo: ErrorInfo) => void): void {
    this.onErrorCallback = callback;
  }

  // Statistics

  /**
   * Get error count for a specific type.
   *
   * @param type error type
   * @returns error count
   */
  getErrorCount(type: ErrorType): number {
    return this.errorCounts[type] || 0;
  }

  /**
   * Get total error count across all types.
   *
   * @returns total error count
   */
  getTotalErrorCount(): number {
    return Object.values(this.errorCounts).reduce(
      (sum, count) => sum + count,
      0,
    );
  }

  /**
   * Clear all error counts.
   */
  clearErrorCounts(): void {
    for (const type in this.errorCounts) {
      this.errorCounts[type as ErrorType] = 0;
    }
    console.debug("Cleared all error counts");
  }

  // Private helper methods

  /**
   * Increment error count for a specific type.
   *
   * @param type error type
   */
  private incrementErrorCount(type: ErrorType): void {
    this.errorCounts[type]++;
  }

  /**
   * Generic error handler that determines the appropriate error type and handles it.
   *
   * @param error the error to handle
   * @returns false (generic errors are treated as non-recoverable by default)
   */
  handleError(error: Error): boolean {
    const message = error.message;

    // Try to categorize the error based on the message content
    if (
      message.includes("connection") ||
      message.includes("connect") ||
      message.includes("network")
    ) {
      return this.handleConnectionError(message, 0, 3);
    } else if (
      message.includes("file") ||
      message.includes("read") ||
      message.includes("write")
    ) {
      return this.handleFileIOError(message, "");
    } else if (message.includes("timeout") || message.includes("timed out")) {
      return this.handleTimeoutError(message, 5000);
    } else {
      // Default to protocol error for unknown errors
      return this.handleProtocolError(message);
    }
  }

  /**
   * Convert error type to string.
   *
   * @param type error type
   * @returns string representation
   */
  private errorTypeToString(type: ErrorType): string {
    return type;
  }
}
