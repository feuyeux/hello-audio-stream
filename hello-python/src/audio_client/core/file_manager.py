"""File I/O operations with SHA-256 checksum calculation"""

import hashlib
import os
from pathlib import Path

CHUNK_SIZE = 65536  # 64KB


async def get_file_size(file_path: str) -> int:
    """Get file size in bytes"""
    return os.path.getsize(file_path)


async def read_chunk(file_path: str, offset: int, length: int) -> bytes:
    """Read a chunk of data from file"""
    with open(file_path, 'rb') as f:
        f.seek(offset)
        return f.read(length)


async def write_chunk(file_path: str, data: bytes, append: bool):
    """Write a chunk of data to file"""
    # Ensure parent directory exists
    Path(file_path).parent.mkdir(parents=True, exist_ok=True)
    
    mode = 'ab' if append else 'wb'
    with open(file_path, mode) as f:
        f.write(data)


async def calculate_checksum(file_path: str) -> str:
    """Calculate SHA-256 checksum of file"""
    sha256 = hashlib.sha256()

    with open(file_path, 'rb') as f:
        while True:
            data = f.read(CHUNK_SIZE)
            if not data:
                break
            sha256.update(data)

    return sha256.hexdigest()


# File writer class for streaming writes
class FileWriter:
    """File writer for streaming chunk writes"""

    def __init__(self, output_path: str):
        self.output_path = output_path
        self.file = None
        self.is_open = False

    async def open(self) -> bool:
        """Open file for writing"""
        try:
            # Ensure parent directory exists
            Path(self.output_path).parent.mkdir(parents=True, exist_ok=True)
            self.file = open(self.output_path, 'wb')
            self.is_open = True
            return True
        except Exception as e:
            return False

    async def write(self, data: bytes) -> bool:
        """Write data to the file"""
        if not self.is_open or self.file is None:
            return False
        try:
            self.file.write(data)
            return True
        except Exception:
            return False

    async def close(self) -> None:
        """Close the file"""
        if self.file is not None:
            self.file.close()
            self.file = None
        self.is_open = False


# Global file writer instance for download_manager compatibility
_file_writer = None


async def open_for_writing(file_path: str) -> bool:
    """Open file for writing (download_manager compatibility)"""
    global _file_writer
    _file_writer = FileWriter(file_path)
    return await _file_writer.open()


async def write(data: bytes) -> bool:
    """Write data to open file (download_manager compatibility)"""
    global _file_writer
    if _file_writer is None:
        return False
    return await _file_writer.write(data)


async def close_writer() -> None:
    """Close the file writer (download_manager compatibility)"""
    global _file_writer
    if _file_writer is not None:
        await _file_writer.close()
        _file_writer = None
