"""
Memory pool manager for reusable buffers.
Singleton pattern implementation for shared buffer pool.
Matches C++ MemoryPoolManager and Java MemoryPoolManager.
"""

import threading
from typing import Optional
from collections import deque
from loguru import logger


class MemoryPoolManager:
    """
    Singleton memory pool manager for buffer reuse.
    Thread-safe buffer allocation and release.
    """
    
    _instance: Optional['MemoryPoolManager'] = None
    _lock = threading.Lock()
    
    def __new__(cls, buffer_size: int = 65536, pool_size: int = 100):
        """
        Singleton pattern - only one instance allowed.
        
        Args:
            buffer_size: Size of each buffer in bytes (default 64KB)
            pool_size: Number of buffers to pre-allocate (default 100)
        """
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, buffer_size: int = 65536, pool_size: int = 100):
        """
        Initialize the memory pool (only once).
        
        Args:
            buffer_size: Size of each buffer in bytes (default 64KB)
            pool_size: Number of buffers to pre-allocate (default 100)
        """
        if self._initialized:
            return
            
        self.buffer_size = buffer_size
        self.pool_size = pool_size
        self.available_buffers: deque[bytearray] = deque()
        self.total_buffers = 0
        self.mutex = threading.Lock()
        
        # Pre-allocate buffers
        for _ in range(pool_size):
            buffer = bytearray(buffer_size)
            self.available_buffers.append(buffer)
            self.total_buffers += 1
        
        self._initialized = True
        logger.info(f"MemoryPoolManager initialized with {pool_size} buffers of {buffer_size} bytes each")
    
    @classmethod
    def get_instance(cls, buffer_size: int = 65536, pool_size: int = 100) -> 'MemoryPoolManager':
        """
        Get the singleton instance.
        
        Args:
            buffer_size: Size of each buffer in bytes (default 64KB)
            pool_size: Number of buffers to pre-allocate (default 100)
            
        Returns:
            The singleton MemoryPoolManager instance
        """
        return cls(buffer_size, pool_size)
    
    def acquire_buffer(self) -> bytearray:
        """
        Acquire a buffer from the pool.
        If pool is empty, allocates a new buffer dynamically.
        
        Returns:
            A buffer of size buffer_size
        """
        with self.mutex:
            if self.available_buffers:
                buffer = self.available_buffers.popleft()
                logger.debug(f"Acquired buffer from pool ({len(self.available_buffers)} remaining)")
                return buffer
            else:
                # Pool exhausted, allocate new buffer
                buffer = bytearray(self.buffer_size)
                self.total_buffers += 1
                logger.debug(f"Pool exhausted, allocated new buffer (total: {self.total_buffers})")
                return buffer
    
    def release_buffer(self, buffer: bytearray) -> None:
        """
        Release a buffer back to the pool.
        
        Args:
            buffer: The buffer to release
        """
        if len(buffer) != self.buffer_size:
            logger.warning(f"Buffer size mismatch: expected {self.buffer_size}, got {len(buffer)}")
            return
        
        with self.mutex:
            # Clear buffer before returning to pool
            for i in range(len(buffer)):
                buffer[i] = 0
            
            self.available_buffers.append(buffer)
            logger.debug(f"Released buffer to pool ({len(self.available_buffers)} available)")
    
    def get_available_buffers(self) -> int:
        """
        Get the number of available buffers in the pool.
        
        Returns:
            Number of available buffers
        """
        with self.mutex:
            return len(self.available_buffers)
    
    def get_total_buffers(self) -> int:
        """
        Get the total number of buffers (available + in-use).
        
        Returns:
            Total number of buffers
        """
        with self.mutex:
            return self.total_buffers
