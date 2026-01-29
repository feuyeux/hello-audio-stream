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
