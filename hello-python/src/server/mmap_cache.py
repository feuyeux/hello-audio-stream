"""File-backed cache for a single audio stream (mmap)."""
import mmap
import os
from pathlib import Path

MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024  # 8 GB


class MmapCache:
    """Memory-mapped file cache."""

    def __init__(self, path: str):
        self._path = path
        self._fd: int | None = None
        self._mm: mmap.mmap | None = None
        self._size = 0
        self._active = False

    def create(self, initial_size: int = 4 * 1024 * 1024) -> None:
        """Create the backing file and map it."""
        dir_path = os.path.dirname(self._path)
        os.makedirs(dir_path, exist_ok=True)
        if os.path.exists(self._path):
            os.remove(self._path)

        self._fd = os.open(self._path, os.O_RDWR | os.O_CREAT | os.O_TRUNC)
        os.ftruncate(self._fd, initial_size)
        self._size = initial_size
        self._mm = mmap.mmap(self._fd, self._size)
        self._active = True

    def write(self, offset: int, data: bytes) -> int:
        """Write data at offset, growing if necessary."""
        if not self._active:
            self.create()
        required = offset + len(data)
        if required > self._size:
            self._resize(max(required, self._size * 2))
        self._mm.seek(offset)
        self._mm.write(data)
        return len(data)

    def read(self, offset: int, length: int) -> bytes:
        """Read up to `length` bytes at `offset`."""
        if not self._active:
            self._open()
        if offset >= self._size:
            return b""
        actual = min(length, self._size - offset)
        self._mm.seek(offset)
        return self._mm.read(actual)

    def finalize(self, final_size: int) -> None:
        """Truncate to final size and flush."""
        self._resize(final_size)
        if self._mm:
            self._mm.flush()

    def close(self) -> None:
        """Unmap and close."""
        if self._mm:
            self._mm.close()
            self._mm = None
        if self._fd is not None:
            os.close(self._fd)
            self._fd = None
        self._active = False

    # ── Internal ─────────────────────────────────────────────────────────

    def _open(self) -> None:
        if not os.path.exists(self._path):
            raise FileNotFoundError(self._path)
        self._fd = os.open(self._path, os.O_RDWR)
        self._size = os.fstat(self._fd).st_size
        if self._size > 0:
            self._mm = mmap.mmap(self._fd, self._size)
        self._active = True

    def _resize(self, new_size: int) -> None:
        if new_size > MAX_CACHE_SIZE:
            raise ValueError(f"Exceeds max cache size: {new_size}")
        if self._mm:
            self._mm.close()
            self._mm = None
        if self._fd is not None:
            os.ftruncate(self._fd, new_size)
        self._size = new_size
        if new_size > 0 and self._fd is not None:
            self._mm = mmap.mmap(self._fd, new_size)
