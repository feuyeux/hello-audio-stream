"""Core client modules containing essential business logic."""

from .websocket_client import WebSocketClient
from .chunk_manager import ChunkManager
from .upload_manager import upload
from .download_manager import download
from .file_manager import (
    get_file_size,
    read_chunk,
    write_chunk,
    calculate_checksum,
    CHUNK_SIZE,
)

__all__ = [
    'WebSocketClient',
    'ChunkManager',
    'upload',
    'download',
    'get_file_size',
    'read_chunk',
    'write_chunk',
    'calculate_checksum',
    'CHUNK_SIZE',
]

# Aliases for backward compatibility
UploadManager = upload
DownloadManager = download
FileManager = None  # Module, not a class
