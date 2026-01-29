// Centralized error handling for the audio stream client.
// Provides consistent error handling, logging, and recovery strategies.
// Matches the Java ErrorHandler interface.

import 'dart:math' as math;
import '../../src/logger.dart';

/// Error types enumeration.
enum ErrorType {
  connectionError('CONNECTION_ERROR'),
  fileIoError('FILE_IO_ERROR'),
  protocolError('PROTOCOL_ERROR'),
  timeoutError('TIMEOUT_ERROR'),
  validationError('VALIDATION_ERROR');

  final String value;
  const ErrorType(this.value);
}

/// Error information class.
class ErrorInfo {
  final ErrorType type;
  final String message;
  final String context;
  final int timestamp;
  final bool recoverable;

  ErrorInfo(
      this.type, this.message, this.context, this.timestamp, this.recoverable);

  @override
  String toString() {
    return 'ErrorInfo{type=${type.value}, message=\'$message\', context=\'$context\', recoverable=$recoverable}';
  }
}

/// Centralized error handling for the audio stream client.
class ErrorHandler {
  static final Map<ErrorType, int> _errorCounts = {
    ErrorType.connectionError: 0,
    ErrorType.fileIoError: 0,
    ErrorType.protocolError: 0,
    ErrorType.timeoutError: 0,
    ErrorType.validationError: 0,
  };

  static void Function(ErrorInfo)? _onErrorCallback;

  // Error reporting

  /// Report an error.
  /// @param type error type
  /// @param message error message
  /// @param context additional context
  /// @param recoverable whether the error is recoverable
  static void reportError(ErrorType type, String message,
      {String context = '', bool recoverable = false}) {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    ErrorInfo errorInfo =
        ErrorInfo(type, message, context, timestamp, recoverable);

    // Increment error count
    _incrementErrorCount(type);

    // Log the error
    String logMessage =
        '[${_errorTypeToString(type)}] $message - Context: $context';

    if (recoverable) {
      Logger.warn(logMessage);
    } else {
      Logger.error(logMessage);
    }

    // Call callback if set
    if (_onErrorCallback != null) {
      _onErrorCallback!(errorInfo);
    }
  }

  // Error handling strategies

  /// Handle connection error with retry logic.
  /// @param message error message
  /// @param retryCount current retry count (will be incremented)
  /// @param maxRetries maximum number of retries
  /// @returns true if should retry, false otherwise
  static bool handleConnectionError(
      String message, int retryCount, int maxRetries) {
    reportError(ErrorType.connectionError, message,
        context: 'Retry $retryCount/$maxRetries',
        recoverable: retryCount < maxRetries);

    return retryCount < maxRetries;
  }

  /// Handle file I/O error.
  /// @param message error message
  /// @param filePath file path that caused the error
  /// @returns false (file I/O errors are not recoverable)
  static bool handleFileIOError(String message, String filePath) {
    reportError(ErrorType.fileIoError, message,
        context: 'File: $filePath', recoverable: false);
    return false;
  }

  /// Handle protocol error.
  /// @param message error message
  /// @param expectedFormat expected format description
  /// @returns false (protocol errors are not recoverable)
  static bool handleProtocolError(String message,
      {String expectedFormat = ''}) {
    String context =
        expectedFormat.isNotEmpty ? 'Expected: $expectedFormat' : '';
    reportError(ErrorType.protocolError, message,
        context: context, recoverable: false);
    return false;
  }

  /// Handle timeout error.
  /// @param message error message
  /// @param timeoutMs timeout value in milliseconds
  /// @returns false (timeout errors are not recoverable by default)
  static bool handleTimeoutError(String message, int timeoutMs) {
    reportError(ErrorType.timeoutError, message,
        context: 'Timeout: ${timeoutMs} ms', recoverable: false);
    return false;
  }

  // Recovery strategies

  /// Determine if an error should be retried.
  /// @param type error type
  /// @param currentAttempt current attempt number
  /// @param maxAttempts maximum number of attempts
  /// @returns true if should retry
  static bool shouldRetry(ErrorType type, int currentAttempt, int maxAttempts) {
    if (currentAttempt >= maxAttempts) {
      return false;
    }

    // Only connection and timeout errors are retryable
    return type == ErrorType.connectionError || type == ErrorType.timeoutError;
  }

  /// Get retry delay in milliseconds using exponential backoff.
  /// @param attempt attempt number (1-based)
  /// @returns delay in milliseconds
  static int getRetryDelayMs(int attempt) {
    // Exponential backoff: 2^(attempt-1) * 1000 ms
    // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
    return (math.pow(2, attempt - 1) * 1000).toInt();
  }

  // Callbacks

  /// Set callback for error events.
  /// @param callback callback function
  static void setOnError(void Function(ErrorInfo) callback) {
    _onErrorCallback = callback;
  }

  // Statistics

  /// Get error count for a specific type.
  /// @param type error type
  /// @returns error count
  static int getErrorCount(ErrorType type) {
    return _errorCounts[type] ?? 0;
  }

  /// Get total error count across all types.
  /// @returns total error count
  static int getTotalErrorCount() {
    return _errorCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Clear all error counts.
  static void clearErrorCounts() {
    for (ErrorType type in _errorCounts.keys) {
      _errorCounts[type] = 0;
    }
    Logger.debug('Cleared all error counts');
  }

  // Private helper methods

  /// Increment error count for a specific type.
  /// @param type error type
  static void _incrementErrorCount(ErrorType type) {
    _errorCounts[type] = (_errorCounts[type] ?? 0) + 1;
  }

  /// Convert error type to string.
  /// @param type error type
  /// @returns string representation
  static String _errorTypeToString(ErrorType type) {
    return type.value;
  }
}
