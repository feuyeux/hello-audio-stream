"""Centralized error handling for the audio stream client.
Provides consistent error handling, logging, and recovery strategies.
Matches the Java ErrorHandler interface.
"""

import time
from enum import Enum
from typing import Optional, Dict, Callable
from .. import logger


class ErrorType(Enum):
    """Error types enumeration."""
    CONNECTION_ERROR = "CONNECTION_ERROR"
    FILE_IO_ERROR = "FILE_IO_ERROR"
    PROTOCOL_ERROR = "PROTOCOL_ERROR"
    TIMEOUT_ERROR = "TIMEOUT_ERROR"
    VALIDATION_ERROR = "VALIDATION_ERROR"


class ErrorInfo:
    """Error information class."""

    def __init__(self, error_type: ErrorType, message: str, context: str,
                 timestamp: float, recoverable: bool):
        self.type = error_type
        self.message = message
        self.context = context
        self.timestamp = timestamp
        self.recoverable = recoverable

    def __str__(self):
        return f"ErrorInfo{{type={self.type.value}, message='{self.message}', " \
            f"context='{self.context}', recoverable={self.recoverable}}}"


class ErrorHandler:
    """Centralized error handling for the audio stream client.
    Provides consistent error handling, logging, and recovery strategies.
    Matches the Java ErrorHandler interface.
    """

    def __init__(self):
        self._error_counts: Dict[ErrorType, int] = {}
        self._on_error_callback: Optional[Callable[[ErrorInfo], None]] = None

        # Initialize error counts for all error types
        for error_type in ErrorType:
            self._error_counts[error_type] = 0

    def report_error(self, error_type: ErrorType, message: str, context: str = "",
                     recoverable: bool = False):
        """Report an error.

        Args:
            error_type: Error type
            message: Error message
            context: Additional context
            recoverable: Whether the error is recoverable
        """
        timestamp = time.time()
        error_info = ErrorInfo(error_type, message,
                               context, timestamp, recoverable)

        # Increment error count
        self._increment_error_count(error_type)

        # Log the error
        log_message = f"[{self._error_type_to_string(error_type)}] {message} - Context: {context}"

        if recoverable:
            logger.warning(log_message)
        else:
            logger.error(log_message)

        # Call callback if set
        if self._on_error_callback:
            self._on_error_callback(error_info)

    def handle_connection_error(self, message: str, retry_count: int, max_retries: int) -> bool:
        """Handle connection error with retry logic.

        Args:
            message: Error message
            retry_count: Current retry count (will be incremented)
            max_retries: Maximum number of retries

        Returns:
            True if should retry, False otherwise
        """
        context = f"Retry {retry_count}/{max_retries}"
        self.report_error(ErrorType.CONNECTION_ERROR, message,
                          context, retry_count < max_retries)

        return retry_count < max_retries

    def handle_file_io_error(self, message: str, file_path: str) -> bool:
        """Handle file I/O error.

        Args:
            message: Error message
            file_path: File path that caused the error

        Returns:
            False (file I/O errors are not recoverable)
        """
        self.report_error(ErrorType.FILE_IO_ERROR, message,
                          f"File: {file_path}", False)
        return False

    def handle_protocol_error(self, message: str, expected_format: str = "") -> bool:
        """Handle protocol error.

        Args:
            message: Error message
            expected_format: Expected format description

        Returns:
            False (protocol errors are not recoverable)
        """
        context = f"Expected: {expected_format}" if expected_format else ""
        self.report_error(ErrorType.PROTOCOL_ERROR, message, context, False)
        return False

    def handle_timeout_error(self, message: str, timeout_ms: int) -> bool:
        """Handle timeout error.

        Args:
            message: Error message
            timeout_ms: Timeout value in milliseconds

        Returns:
            False (timeout errors are not recoverable by default)
        """
        context = f"Timeout: {timeout_ms} ms"
        self.report_error(ErrorType.TIMEOUT_ERROR, message, context, False)
        return False

    def should_retry(self, error_type: ErrorType, current_attempt: int, max_attempts: int) -> bool:
        """Determine if an error should be retried.

        Args:
            error_type: Error type
            current_attempt: Current attempt number
            max_attempts: Maximum number of attempts

        Returns:
            True if should retry
        """
        if current_attempt >= max_attempts:
            return False

        # Only connection and timeout errors are retryable
        return error_type in [ErrorType.CONNECTION_ERROR, ErrorType.TIMEOUT_ERROR]

    def get_retry_delay_ms(self, attempt: int) -> int:
        """Get retry delay in milliseconds using exponential backoff.

        Args:
            attempt: Attempt number (1-based)

        Returns:
            Delay in milliseconds
        """
        # Exponential backoff: 2^(attempt-1) * 1000 ms
        # Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s, etc.
        return int(2 ** (attempt - 1) * 1000)

    def set_on_error(self, callback: Callable[[ErrorInfo], None]):
        """Set callback for error events.

        Args:
            callback: Callback function
        """
        self._on_error_callback = callback

    def get_error_count(self, error_type: ErrorType) -> int:
        """Get error count for a specific type.

        Args:
            error_type: Error type

        Returns:
            Error count
        """
        return self._error_counts.get(error_type, 0)

    def get_total_error_count(self) -> int:
        """Get total error count across all types.

        Returns:
            Total error count
        """
        return sum(self._error_counts.values())

    def clear_error_counts(self):
        """Clear all error counts."""
        for error_type in ErrorType:
            self._error_counts[error_type] = 0
        logger.debug("Cleared all error counts")

    def _increment_error_count(self, error_type: ErrorType):
        """Increment error count for a specific type.

        Args:
            error_type: Error type
        """
        self._error_counts[error_type] = self._error_counts.get(
            error_type, 0) + 1

    def _error_type_to_string(self, error_type: ErrorType) -> str:
        """Convert error type to string.

        Args:
            error_type: Error type

        Returns:
            String representation
        """
        return error_type.value
