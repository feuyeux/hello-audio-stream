using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace AudioStreamCache.Client.Util;

/// <summary>
/// Centralized error handling for the audio stream client.
/// Provides consistent error handling, logging, and recovery strategies.
/// Matches the Java ErrorHandler interface.
/// </summary>
public static class ErrorHandler
{
    private static Dictionary<ErrorType, int> _errorCounts = new Dictionary<ErrorType, int>()
    {
        { ErrorType.CONNECTION_ERROR, 0 },
        { ErrorType.FILE_IO_ERROR, 0 },
        { ErrorType.PROTOCOL_ERROR, 0 },
        { ErrorType.TIMEOUT_ERROR, 0 },
        { ErrorType.VALIDATION_ERROR, 0 }
    };

    private static Action<ErrorInfo>? _onErrorCallback = null;

    /// <summary>
    /// Error types enumeration.
    /// </summary>
    public enum ErrorType
    {
        CONNECTION_ERROR,
        FILE_IO_ERROR,
        PROTOCOL_ERROR,
        TIMEOUT_ERROR,
        VALIDATION_ERROR
    }

    /// <summary>
    /// Error information class.
    /// </summary>
    public class ErrorInfo
    {
        public ErrorType Type { get; }
        public string Message { get; }
        public string Context { get; }
        public long Timestamp { get; }
        public bool Recoverable { get; }

        public ErrorInfo(ErrorType type, string message, string context, long timestamp, bool recoverable)
        {
            Type = type;
            Message = message;
            Context = context;
            Timestamp = timestamp;
            Recoverable = recoverable;
        }

        public override string ToString()
        {
            return $"ErrorInfo{{type={Type}, message='{Message}', context='{Context}', recoverable={Recoverable}}}";
        }
    }

    // Error reporting

    /// <summary>
    /// Report an error.
    /// </summary>
    /// <param name="type">error type</param>
    /// <param name="message">error message</param>
    /// <param name="context">additional context</param>
    /// <param name="recoverable">whether the error is recoverable</param>
    public static void ReportError(ErrorType type, string message, string context = "", bool recoverable = false)
    {
        long timestamp = DateTimeOffset.Now.ToUnixTimeMilliseconds();
        var errorInfo = new ErrorInfo(type, message, context, timestamp, recoverable);

        // Increment error count
        IncrementErrorCount(type);

        // Log the error
        string logMessage = $"[{ErrorTypeToString(type)}] {message} - Context: {context}";

        if (recoverable)
        {
            Logger.Warn(logMessage);
        }
        else
        {
            Logger.Error(logMessage);
        }

        // Call callback if set
        if (_onErrorCallback != null)
        {
            _onErrorCallback(errorInfo);
        }
    }

    // Error handling strategies

    /// <summary>
    /// Handle connection error with retry logic.
    /// </summary>
    /// <param name="message">error message</param>
    /// <param name="retryCount">current retry count (will be incremented)</param>
    /// <param name="maxRetries">maximum number of retries</param>
    /// <returns>true if should retry, false otherwise</returns>
    public static bool HandleConnectionError(string message, int retryCount, int maxRetries)
    {
        ReportError(ErrorType.CONNECTION_ERROR, message,
                $"Retry {retryCount}/{maxRetries}", retryCount < maxRetries);

        return retryCount < maxRetries;
    }

    /// <summary>
    /// Handle file I/O error.
    /// </summary>
    /// <param name="message">error message</param>
    /// <param name="filePath">file path that caused the error</param>
    /// <returns>false (file I/O errors are not recoverable)</returns>
    public static bool HandleFileIOError(string message, string filePath)
    {
        ReportError(ErrorType.FILE_IO_ERROR, message, "File: " + filePath, false);
        return false;
    }

    /// <summary>
    /// Handle protocol error.
    /// </summary>
    /// <param name="message">error message</param>
    /// <param name="expectedFormat">expected format description</param>
    /// <returns>false (protocol errors are not recoverable)</returns>
    public static bool HandleProtocolError(string message, string expectedFormat = "")
    {
        string context = string.IsNullOrEmpty(expectedFormat) ? "" : "Expected: " + expectedFormat;
        ReportError(ErrorType.PROTOCOL_ERROR, message, context, false);
        return false;
    }

    /// <summary>
    /// Handle timeout error.
    /// </summary>
    /// <param name="message">error message</param>
    /// <param name="timeoutMs">timeout value in milliseconds</param>
    /// <returns>false (timeout errors are not recoverable by default)</returns>
    public static bool HandleTimeoutError(string message, int timeoutMs)
    {
        ReportError(ErrorType.TIMEOUT_ERROR, message,
                $"Timeout: {timeoutMs} ms", false);
        return false;
    }

    // Recovery strategies

    /// <summary>
    /// Determine if an error should be retried.
    /// </summary>
    /// <param name="type">error type</param>
    /// <param name="currentAttempt">current attempt number</param>
    /// <param name="maxAttempts">maximum number of attempts</param>
    /// <returns>true if should retry</returns>
    public static bool ShouldRetry(ErrorType type, int currentAttempt, int maxAttempts)
    {
        if (currentAttempt >= maxAttempts)
        {
            return false;
        }

        // Only connection and timeout errors are retryable
        return type == ErrorType.CONNECTION_ERROR || type == ErrorType.TIMEOUT_ERROR;
    }

    /// <summary>
    /// Get retry delay in milliseconds using exponential backoff.
    /// </summary>
    /// <param name="attempt">attempt number (1-based)</param>
    /// <returns>delay in milliseconds</returns>
    public static int GetRetryDelayMs(int attempt)
    {
        // Exponential backoff: 2^(attempt-1) * 1000 ms
        // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
        return (int)(Math.Pow(2, attempt - 1) * 1000);
    }

    // Callbacks

    /// <summary>
    /// Set callback for error events.
    /// </summary>
    /// <param name="callback">callback function</param>
    public static void SetOnError(Action<ErrorInfo> callback)
    {
        _onErrorCallback = callback;
    }

    // Statistics

    /// <summary>
    /// Get error count for a specific type.
    /// </summary>
    /// <param name="type">error type</param>
    /// <returns>error count</returns>
    public static int GetErrorCount(ErrorType type)
    {
        return _errorCounts.TryGetValue(type, out int count) ? count : 0;
    }

    /// <summary>
    /// Get total error count across all types.
    /// </summary>
    /// <returns>total error count</returns>
    public static int GetTotalErrorCount()
    {
        int total = 0;
        foreach (var count in _errorCounts.Values)
        {
            total += count;
        }
        return total;
    }

    /// <summary>
    /// Clear all error counts.
    /// </summary>
    public static void ClearErrorCounts()
    {
        foreach (var type in Enum.GetValues(typeof(ErrorType)))
        {
            _errorCounts[(ErrorType)type] = 0;
        }
        Logger.Debug("Cleared all error counts");
    }

    // Private helper methods

    /// <summary>
    /// Increment error count for a specific type.
    /// </summary>
    /// <param name="type">error type</param>
    private static void IncrementErrorCount(ErrorType type)
    {
        if (_errorCounts.ContainsKey(type))
        {
            _errorCounts[type]++;
        }
        else
        {
            _errorCounts[type] = 1;
        }
    }

    /// <summary>
    /// Convert error type to string.
    /// </summary>
    /// <param name="type">error type</param>
    /// <returns>string representation</returns>
    private static string ErrorTypeToString(ErrorType type)
    {
        return type switch
        {
            ErrorType.CONNECTION_ERROR => "CONNECTION_ERROR",
            ErrorType.FILE_IO_ERROR => "FILE_IO_ERROR",
            ErrorType.PROTOCOL_ERROR => "PROTOCOL_ERROR",
            ErrorType.TIMEOUT_ERROR => "TIMEOUT_ERROR",
            ErrorType.VALIDATION_ERROR => "VALIDATION_ERROR",
            _ => "UNKNOWN_ERROR"
        };
    }
}
