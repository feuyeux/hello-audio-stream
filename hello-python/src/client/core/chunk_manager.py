"""Chunk manager for handling file chunking operations"""

CHUNK_SIZE = 65536  # 64KB
UPLOAD_CHUNK_SIZE = 8192  # 8KB for WebSocket to avoid fragmentation


class ChunkManager:
    """Manager for chunk operations"""
    
    @staticmethod
    def get_chunk_size() -> int:
        """Get default chunk size for file operations"""
        return CHUNK_SIZE
    
    @staticmethod
    def get_upload_chunk_size() -> int:
        """Get chunk size for upload operations"""
        return UPLOAD_CHUNK_SIZE
    
    @staticmethod
    def calculate_chunks_needed(file_size: int, chunk_size: int) -> int:
        """Calculate number of chunks needed for a file"""
        return (file_size + chunk_size - 1) // chunk_size
