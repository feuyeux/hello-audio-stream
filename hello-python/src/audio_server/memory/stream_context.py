"""
Stream context for managing active audio streams.
Contains stream metadata and cache file handle.
Matches C++ StreamContext structure and Java StreamContext class.
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
import threading
from .memory_mapped_cache import MemoryMappedCache


class StreamStatus(Enum):
    """Stream status enumeration"""
    UPLOADING = "UPLOADING"
    READY = "READY"
    ERROR = "ERROR"


@dataclass
class StreamContext:
    """
    Stream context containing metadata and state for a single stream.
    Thread-safe with Lock for concurrent access.
    
    Attributes:
        stream_id: Unique identifier for the stream
        cache_path: Path to the cache file
        mmap_file: Memory-mapped cache instance
        current_offset: Current write position in bytes
        total_size: Total size of the stream in bytes
        created_at: Timestamp when stream was created
        last_accessed_at: Timestamp of last access
        status: Current status of the stream
        lock: Thread lock for concurrent access
    """
    stream_id: str
    cache_path: str = ""
    mmap_file: Optional[MemoryMappedCache] = None
    current_offset: int = 0
    total_size: int = 0
    created_at: datetime = field(default_factory=datetime.now)
    last_accessed_at: datetime = field(default_factory=datetime.now)
    status: StreamStatus = StreamStatus.UPLOADING
    lock: threading.Lock = field(default_factory=threading.Lock)
    
    def update_access_time(self) -> None:
        """Update the last accessed timestamp"""
        self.last_accessed_at = datetime.now()
