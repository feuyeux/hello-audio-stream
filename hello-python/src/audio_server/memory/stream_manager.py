"""
Stream manager for managing active audio streams.
Thread-safe registry of stream contexts.
Matches C++ StreamManager and Java StreamManager functionality.
"""

import os
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from pathlib import Path
from loguru import logger

from .stream_context import StreamContext, StreamStatus
from .memory_mapped_cache import MemoryMappedCache


class StreamManager:
    """
    Singleton stream manager for managing multiple concurrent streams.
    Thread-safe stream creation, retrieval, and deletion.
    """

    _instance: Optional['StreamManager'] = None
    _lock = threading.Lock()

    def __new__(cls, cache_directory: str = "cache"):
        """
        Singleton pattern - only one instance allowed.

        Args:
            cache_directory: Directory for cache files
        """
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self, cache_directory: str = "cache"):
        """
        Initialize the stream manager (only once).

        Args:
            cache_directory: Directory for cache files
        """
        if self._initialized:
            return

        self.cache_directory = cache_directory
        self.streams: Dict[str, StreamContext] = {}
        self.mutex = threading.Lock()

        # Create cache directory if it doesn't exist
        Path(cache_directory).mkdir(parents=True, exist_ok=True)

        self._initialized = True
        logger.info(
            f"StreamManager initialized with cache directory: {cache_directory}")

    @classmethod
    def get_instance(cls, cache_directory: str = "cache") -> 'StreamManager':
        """
        Get the singleton instance.

        Args:
            cache_directory: Directory for cache files

        Returns:
            The singleton StreamManager instance
        """
        return cls(cache_directory)

    def create_stream(self, stream_id: str) -> bool:
        """
        Create a new stream.

        Args:
            stream_id: Unique identifier for the stream

        Returns:
            True if successful, False if stream already exists
        """
        with self.mutex:
            # Check if stream already exists
            if stream_id in self.streams:
                logger.warning(f"Stream already exists: {stream_id}")
                return False

            try:
                # Create new stream context
                cache_path = self._get_cache_path(stream_id)
                context = StreamContext(
                    stream_id=stream_id,
                    cache_path=cache_path,
                    current_offset=0,
                    total_size=0,
                    status=StreamStatus.UPLOADING,
                    created_at=datetime.now(),
                    last_accessed_at=datetime.now()
                )

                # Create memory-mapped cache file
                mmap_file = MemoryMappedCache(cache_path)
                context.mmap_file = mmap_file

                # Add to registry
                self.streams[stream_id] = context

                logger.info(
                    f"Created stream: {stream_id} at path: {cache_path}")
                return True

            except Exception as e:
                logger.error(f"Failed to create stream {stream_id}: {e}")
                return False

    def get_stream(self, stream_id: str) -> Optional[StreamContext]:
        """
        Get a stream context.

        Args:
            stream_id: Unique identifier for the stream

        Returns:
            Stream context or None if not found
        """
        with self.mutex:
            context = self.streams.get(stream_id)
            if context:
                context.update_access_time()
            return context

    def delete_stream(self, stream_id: str) -> bool:
        """
        Delete a stream.

        Args:
            stream_id: Unique identifier for the stream

        Returns:
            True if successful
        """
        with self.mutex:
            context = self.streams.get(stream_id)
            if not context:
                logger.warning(f"Stream not found for deletion: {stream_id}")
                return False

            try:
                # Close memory-mapped file
                if context.mmap_file:
                    context.mmap_file.close()

                # Remove cache file
                if os.path.exists(context.cache_path):
                    os.remove(context.cache_path)

                # Remove from registry
                del self.streams[stream_id]

                logger.info(f"Deleted stream: {stream_id}")
                return True

            except Exception as e:
                logger.error(f"Failed to delete stream {stream_id}: {e}")
                return False

    def list_active_streams(self) -> List[str]:
        """
        List all active streams.

        Returns:
            List of stream IDs
        """
        with self.mutex:
            return list(self.streams.keys())

    def write_chunk(self, stream_id: str, data: bytes) -> bool:
        """
        Write a chunk of data to a stream.

        Args:
            stream_id: Unique identifier for the stream
            data: Data to write

        Returns:
            True if successful
        """
        stream = self.get_stream(stream_id)
        if not stream:
            logger.error(f"Stream not found for write: {stream_id}")
            return False

        with stream.lock:
            if stream.status != StreamStatus.UPLOADING:
                logger.error(f"Stream {stream_id} is not in uploading state")
                return False

            try:
                # Write data to memory-mapped file
                written = stream.mmap_file.write(stream.current_offset, data)

                if written > 0:
                    stream.current_offset += written
                    stream.total_size += written
                    stream.update_access_time()

                    logger.debug(
                        f"Wrote {written} bytes to stream {stream_id} at offset {stream.current_offset - written}")
                    return True
                else:
                    logger.error(f"Failed to write data to stream {stream_id}")
                    return False

            except Exception as e:
                logger.error(f"Error writing to stream {stream_id}: {e}")
                return False

    def read_chunk(self, stream_id: str, offset: int, length: int) -> bytes:
        """
        Read a chunk of data from a stream.

        Args:
            stream_id: Unique identifier for the stream
            offset: Starting position
            length: Number of bytes to read

        Returns:
            Data read, or empty bytes if error
        """
        stream = self.get_stream(stream_id)
        if not stream:
            logger.error(f"Stream not found for read: {stream_id}")
            return b''

        with stream.lock:
            try:
                # Read data from memory-mapped file
                data = stream.mmap_file.read(offset, length)
                stream.update_access_time()

                logger.debug(
                    f"Read {len(data)} bytes from stream {stream_id} at offset {offset}")
                return data

            except Exception as e:
                logger.error(f"Error reading from stream {stream_id}: {e}")
                return b''

    def finalize_stream(self, stream_id: str) -> bool:
        """
        Finalize a stream (flush and mark as ready).

        Args:
            stream_id: Unique identifier for the stream

        Returns:
            True if successful
        """
        stream = self.get_stream(stream_id)
        if not stream:
            logger.error(f"Stream not found for finalization: {stream_id}")
            return False

        with stream.lock:
            if stream.status != StreamStatus.UPLOADING:
                logger.warning(
                    f"Stream {stream_id} is not in uploading state for finalization")
                return False

            try:
                # Finalize memory-mapped file
                if stream.mmap_file.finalize(stream.total_size):
                    stream.status = StreamStatus.READY
                    stream.update_access_time()

                    logger.info(
                        f"Finalized stream: {stream_id} with {stream.total_size} bytes")
                    return True
                else:
                    logger.error(
                        f"Failed to finalize memory-mapped file for stream {stream_id}")
                    return False

            except Exception as e:
                logger.error(f"Error finalizing stream {stream_id}: {e}")
                return False

    def cleanup_old_streams(self, max_age_hours: int = 24) -> None:
        """
        Clean up old streams (older than max_age_hours).

        Args:
            max_age_hours: Maximum age in hours (default 24)
        """
        with self.mutex:
            now = datetime.now()
            cutoff = timedelta(hours=max_age_hours)

            to_remove = []
            for stream_id, context in self.streams.items():
                age = now - context.last_accessed_at
                if age > cutoff:
                    to_remove.append(stream_id)

            for stream_id in to_remove:
                logger.info(f"Cleaning up old stream: {stream_id}")
                self.delete_stream(stream_id)

    def _get_cache_path(self, stream_id: str) -> str:
        """
        Get cache file path for a stream.

        Args:
            stream_id: Unique identifier for the stream

        Returns:
            Cache file path
        """
        return os.path.join(self.cache_directory, f"{stream_id}.cache")
