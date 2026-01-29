"""Memory-mapped cache for efficient file I/O operations"""

import mmap
import os
import threading
from typing import Optional, IO
from loguru import logger

DEFAULT_PAGE_SIZE = 64 * 1024 * 1024
MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024


class MemoryMappedCache:
    """
    Memory-mapped cache implementation for efficient file operations.
    Thread-safe with RLock for concurrent access.
    """

    def __init__(self, path: str):
        self.path = path
        self.file: Optional[IO[bytes]] = None
        self.mmap: Optional[mmap.mmap] = None
        self.size = 0
        self.is_open = False
        self._lock = threading.RLock()  # Reentrant lock for thread safety

    def create(self, path: str, initial_size: int = 0) -> bool:
        with self._lock:
            return self._create_internal(path, initial_size)

    def _create_internal(self, path: str, initial_size: int = 0) -> bool:
        logger.debug(
            f"Creating mmap file: {path} with initial size: {initial_size}")

        try:
            # Ensure parent directory exists
            parent_dir = os.path.dirname(path)
            if parent_dir:
                os.makedirs(parent_dir, exist_ok=True)

            if os.path.exists(path):
                os.remove(path)

            # Create new file with w+b mode (write + binary, creates if not exists)
            self.file = open(path, 'w+b')
            if initial_size > 0:
                self.file.truncate(initial_size)
                self.size = initial_size
            else:
                self.size = 0

            if self.size > 0:
                self.map_file()

            self.is_open = True
            logger.debug(
                f"Created mmap file: {path} with size: {initial_size}")
            return True

        except Exception as e:
            logger.error(f"Error creating file {path}: {e}")
            return False

    def open(self, path: str) -> bool:
        with self._lock:
            return self._open_internal(path)

    def _open_internal(self, path: str) -> bool:
        logger.debug(f"Opening mmap file: {path}")

        try:
            if not os.path.exists(path):
                logger.error(f"File does not exist: {path}")
                return False

            self.file = open(path, 'r+b')
            self.size = os.path.getsize(path)

            if self.size > 0:
                self.map_file()

            self.is_open = True
            logger.debug(f"Opened mmap file: {path} with size: {self.size}")
            return True

        except Exception as e:
            logger.error(f"Error opening file {path}: {e}")
            return False

    def close(self) -> None:
        with self._lock:
            if self.is_open:
                self.unmap_file()
                logger.debug(f"Closed mmap file: {self.path}")

    def write(self, offset: int, data: bytes) -> int:
        with self._lock:
            try:
                if not self.is_open or self.mmap is None:
                    initial_size = offset + len(data)
                    if not self._create_internal(self.path, initial_size):
                        return 0

                required_size = offset + len(data)
                if required_size > self.size:
                    if not self._resize_internal(required_size):
                        logger.error(
                            "Failed to resize file for write operation")
                        return 0

                assert self.mmap is not None
                self.mmap[offset:offset + len(data)] = data

                logger.debug(
                    f"Wrote {len(data)} bytes to {self.path} at offset {offset}")
                return len(data)

            except Exception as e:
                logger.error(f"Error writing to mapped file {self.path}: {e}")
                return 0

    def read(self, offset: int, length: int) -> bytes:
        with self._lock:
            try:
                if not self.is_open or self.mmap is None:
                    logger.debug(
                        f"File not open, attempting to open for reading: {self.path}")
                    if not self._open_internal(self.path):
                        logger.error(
                            f"Failed to open file for reading: {self.path}")
                        return b''

                if offset >= self.size:
                    logger.debug(
                        f"Read offset {offset} at or beyond file size {self.size} - end of file")
                    return b''

                actual_length = min(length, self.size - offset)
                assert self.mmap is not None
                data = self.mmap[offset:offset + actual_length]

                logger.debug(
                    f"Read {actual_length} bytes from {self.path} at offset {offset}")
                return data

            except Exception as e:
                logger.error(
                    f"Error reading from mapped file {self.path}: {e}")
                return b''

    def get_size(self) -> int:
        with self._lock:
            return self.size

    def get_path(self) -> str:
        return self.path

    def get_is_open(self) -> bool:
        with self._lock:
            return self.is_open

    def resize(self, new_size: int) -> bool:
        with self._lock:
            return self._resize_internal(new_size)

    def _resize_internal(self, new_size: int) -> bool:
        try:
            if not self.is_open:
                logger.error(f"File not open for resize: {self.path}")
                return False

            if new_size == self.size:
                return True

            # Unmap only, don't close the file
            if self.mmap is not None:
                self.mmap.close()
                self.mmap = None

            assert self.file is not None
            self.file.truncate(new_size)
            self.size = new_size

            if self.size > 0:
                self.map_file()

            logger.debug(
                f"Resized and remapped file {self.path} to {new_size} bytes")
            return True

        except Exception as e:
            logger.error(f"Error resizing file {self.path}: {e}")
            return False

    def finalize(self, final_size: int) -> bool:
        with self._lock:
            try:
                if not self.is_open:
                    logger.warning(
                        f"File not open for finalization: {self.path}")
                    return False

                if not self._resize_internal(final_size):
                    logger.error(
                        f"Failed to resize file during finalization: {self.path}")
                    return False

                if self.mmap is not None:
                    self.mmap.flush()

                logger.debug(
                    f"Finalized file: {self.path} with size: {final_size}")
                return True

            except Exception as e:
                logger.error(f"Error finalizing file {self.path}: {e}")
                return False

    def map_file(self) -> None:
        if self.file is None:
            raise ValueError("File is not open")

        self.mmap = mmap.mmap(self.file.fileno(), 0)
        logger.debug(
            f"Successfully mapped file: {self.path} ({self.size} bytes)")

    def unmap_file(self) -> None:
        if self.mmap is not None:
            self.mmap.close()
            self.mmap = None

        if self.file is not None:
            self.file.close()
            self.file = None

        self.is_open = False

    def __del__(self):
        self.close()


# Alias for backward compatibility
MmapCache = MemoryMappedCache
