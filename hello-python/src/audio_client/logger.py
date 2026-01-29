"""Logging utility with support for different log levels"""

from datetime import datetime

_verbose_enabled = False


def init(verbose: bool):
    """Initialize logger with verbose flag"""
    global _verbose_enabled
    _verbose_enabled = verbose


def _format_timestamp() -> str:
    """Format current timestamp"""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


def info(message: str):
    """Log info message"""
    print(f"[{_format_timestamp()}] [info] {message}")


def error(message: str):
    """Log error message"""
    print(f"[{_format_timestamp()}] [error] {message}")


def warn(message: str):
    """Log warning message"""
    print(f"[{_format_timestamp()}] [warn] {message}")


def warning(message: str):
    """Log warning message (alias for warn)"""
    warn(message)


def debug(message: str):
    """Log debug message (only if verbose enabled)"""
    if _verbose_enabled:
        print(f"[{_format_timestamp()}] [debug] {message}")


def phase(message: str):
    """Log phase separator"""
    print()
    print(f"[{_format_timestamp()}] [info] === {message} ===")
