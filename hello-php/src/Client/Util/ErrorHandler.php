<?php

namespace AudioStreamClient\Util;

use AudioStreamClient\Logger;

/**
 * Centralized error handling for the audio stream client.
 * Provides consistent error handling, logging, and recovery strategies.
 * Matches the Java ErrorHandler interface.
 */
class ErrorHandler
{
    private static array $errorCounts = [
        'CONNECTION_ERROR' => 0,
        'FILE_IO_ERROR' => 0,
        'PROTOCOL_ERROR' => 0,
        'TIMEOUT_ERROR' => 0,
        'VALIDATION_ERROR' => 0,
    ];
    
    private static $onErrorCallback = null;
    
    public const CONNECTION_ERROR = 'CONNECTION_ERROR';
    public const FILE_IO_ERROR = 'FILE_IO_ERROR';
    public const PROTOCOL_ERROR = 'PROTOCOL_ERROR';
    public const TIMEOUT_ERROR = 'TIMEOUT_ERROR';
    public const VALIDATION_ERROR = 'VALIDATION_ERROR';
    
    /**
     * Report an error.
     *
     * @param string $type Error type
     * @param string $message Error message
     * @param string $context Additional context
     * @param bool $recoverable Whether the error is recoverable
     */
    public static function reportError(string $type, string $message, string $context = '', bool $recoverable = false): void
    {
        $timestamp = microtime(true);
        
        // Increment error count
        self::incrementErrorCount($type);
        
        // Log the error
        $logMessage = "[{$type}] {$message} - Context: {$context}";
        
        if ($recoverable) {
            Logger::warn($logMessage);
        } else {
            Logger::error($logMessage);
        }
        
        // Call callback if set
        if (self::$onErrorCallback !== null) {
            $errorInfo = new ErrorInfo($type, $message, $context, $timestamp, $recoverable);
            call_user_func(self::$onErrorCallback, $errorInfo);
        }
    }
    
    /**
     * Handle connection error with retry logic.
     *
     * @param string $message Error message
     * @param int $retryCount Current retry count (will be incremented)
     * @param int $maxRetries Maximum number of retries
     * @return bool True if should retry, false otherwise
     */
    public static function handleConnectionError(string $message, int $retryCount, int $maxRetries): bool
    {
        $context = "Retry {$retryCount}/{$maxRetries}";
        self::reportError(self::CONNECTION_ERROR, $message, $context, $retryCount < $maxRetries);
        
        return $retryCount < $maxRetries;
    }
    
    /**
     * Handle file I/O error.
     *
     * @param string $message Error message
     * @param string $filePath File path that caused the error
     * @return bool False (file I/O errors are not recoverable)
     */
    public static function handleFileIOError(string $message, string $filePath): bool
    {
        self::reportError(self::FILE_IO_ERROR, $message, "File: {$filePath}", false);
        return false;
    }
    
    /**
     * Handle protocol error.
     *
     * @param string $message Error message
     * @param string $expectedFormat Expected format description
     * @return bool False (protocol errors are not recoverable)
     */
    public static function handleProtocolError(string $message, string $expectedFormat = ''): bool
    {
        $context = $expectedFormat ? "Expected: {$expectedFormat}" : "";
        self::reportError(self::PROTOCOL_ERROR, $message, $context, false);
        return false;
    }
    
    /**
     * Handle timeout error.
     *
     * @param string $message Error message
     * @param int $timeoutMs Timeout value in milliseconds
     * @return bool False (timeout errors are not recoverable by default)
     */
    public static function handleTimeoutError(string $message, int $timeoutMs): bool
    {
        $context = "Timeout: {$timeoutMs} ms";
        self::reportError(self::TIMEOUT_ERROR, $message, $context, false);
        return false;
    }
    
    /**
     * Determine if an error should be retried.
     *
     * @param string $type Error type
     * @param int $currentAttempt Current attempt number
     * @param int $maxAttempts Maximum number of attempts
     * @return bool True if should retry
     */
    public static function shouldRetry(string $type, int $currentAttempt, int $maxAttempts): bool
    {
        if ($currentAttempt >= $maxAttempts) {
            return false;
        }
        
        // Only connection and timeout errors are retryable
        return $type === self::CONNECTION_ERROR || $type === self::TIMEOUT_ERROR;
    }
    
    /**
     * Get retry delay in milliseconds using exponential backoff.
     *
     * @param int $attempt Attempt number (1-based)
     * @return int Delay in milliseconds
     */
    public static function getRetryDelayMs(int $attempt): int
    {
        // Exponential backoff: 2^(attempt-1) * 1000 ms
        // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
        return (int) (pow(2, $attempt - 1) * 1000);
    }
    
    /**
     * Set callback for error events.
     *
     * @param callable $callback Callback function
     */
    public static function setOnError($callback): void
    {
        self::$onErrorCallback = $callback;
    }
    
    /**
     * Get error count for a specific type.
     *
     * @param string $type Error type
     * @return int Error count
     */
    public static function getErrorCount(string $type): int
    {
        return self::$errorCounts[$type] ?? 0;
    }
    
    /**
     * Get total error count across all types.
     *
     * @return int Total error count
     */
    public static function getTotalErrorCount(): int
    {
        return array_sum(self::$errorCounts);
    }
    
    /**
     * Clear all error counts.
     */
    public static function clearErrorCounts(): void
    {
        foreach (array_keys(self::$errorCounts) as $type) {
            self::$errorCounts[$type] = 0;
        }
        Logger::debug('Cleared all error counts');
    }
    
    /**
     * Increment error count for a specific type.
     *
     * @param string $type Error type
     */
    private static function incrementErrorCount(string $type): void
    {
        if (isset(self::$errorCounts[$type])) {
            self::$errorCounts[$type]++;
        }
    }
}

class ErrorInfo
{
    public string $type;
    public string $message;
    public string $context;
    public float $timestamp;
    public bool $recoverable;
    
    public function __construct(string $type, string $message, string $context, float $timestamp, bool $recoverable)
    {
        $this->type = $type;
        $this->message = $message;
        $this->context = $context;
        $this->timestamp = $timestamp;
        $this->recoverable = $recoverable;
    }
    
    public function __toString(): string
    {
        return "ErrorInfo{type={$this->type}, message='{$this->message}', context='{$this->context}', recoverable={$this->recoverable}}";
    }
}