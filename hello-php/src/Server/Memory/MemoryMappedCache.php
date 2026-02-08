<?php

/**
 * Memory-mapped cache for efficient file I/O using FFI.
 * Provides write, read, resize, and finalize operations.
 * Matches Python MmapCache functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Memory;

use AudioStreamClient\Logger;
use FFI;
use RuntimeException;

// Configuration constants - follows unified mmap implementation specification v2.0.0
const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8GB
const SEGMENT_SIZE = 1 * 1024 * 1024 * 1024; // 1GB per segment
const BATCH_OPERATION_LIMIT = 1000; // Max batch operations

/**
 * Memory-mapped cache implementation.
 */
class MemoryMappedCache
{
    private string $path;
    private int $size;
    private bool $_isOpen;
    
    // FFI instance
    private ?FFI $ffi = null;
    private bool $isWindows;
    
    // Mapped memory pointer
    private $mappedAddr = null;
    
    // Windows Handles
    private $hFile = null;
    private $hMap = null;
    
    // File descriptor for POSIX
    private $fd = -1;

    /**
     * Create a new MemoryMappedCache.
     *
     * @param string $filePath Path to the cache file
     */
    public function __construct(string $filePath)
    {
        $this->path = $filePath;
        $this->size = 0;
        $this->_isOpen = false;
        $this->isWindows = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN';
        
        try {
            if ($this->isWindows) {
                // Warning: FFI on Windows might need adjustments for DLL paths or types
                $this->ffi = FFI::cdef("
                    typedef void* HANDLE;
                    typedef void* LPVOID;
                    typedef unsigned long DWORD;
                    typedef int BOOL;
                    typedef unsigned long long UINT64;
                    
                    HANDLE CreateFileA(const char* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
                    HANDLE CreateFileMappingA(HANDLE hFile, void* lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, const char* lpName);
                    LPVOID MapViewOfFile(HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, size_t dwNumberOfBytesToMap);
                    BOOL UnmapViewOfFile(LPVOID lpBaseAddress);
                    BOOL CloseHandle(HANDLE hObject);
                    BOOL SetEndOfFile(HANDLE hFile);
                    DWORD SetFilePointer(HANDLE hFile, long lDistanceToMove, long* lpDistanceToMoveHigh, DWORD dwMoveMethod);
                    BOOL FlushViewOfFile(LPVOID lpBaseAddress, size_t dwNumberOfBytesToFlush);
                ", "kernel32.dll");
            } else {
                $this->ffi = FFI::cdef("
                    void *mmap(void *addr, size_t length, int prot, int flags, int fd, long offset);
                    int munmap(void *addr, size_t length);
                    int open(const char *pathname, int flags, int mode);
                    int close(int fd);
                    int ftruncate(int fd, long length);
                    int msync(void *addr, size_t length, int flags);
                ", "libc.so.6"); 
            }
        } catch (\Exception $e) {
            Logger::error("FFI not available: " . $e->getMessage());
            $this->ffi = null;
        }
    }

    /**
     * Create a new memory-mapped file.
     *
     * @param string $filePath Path to the file
     * @param int $initialSize Initial size in bytes
     * @return bool True if successful
     */
    public function create(string $filePath, int $initialSize = 0): bool
    {
        $this->path = $filePath;
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        
        if ($this->ffi === null) {
            Logger::error("FFI is not initialized, cannot create mmap file.");
            return false;
        }

        if ($this->isWindows) {
            return $this->createWindows($initialSize);
        } else {
            return $this->createPosix($initialSize);
        }
    }
    
    private function createWindows(int $initialSize): bool {
        $this->hFile = $this->ffi->CreateFileA(
            $this->path, 
            0xC0000000, // GENERIC_READ | GENERIC_WRITE
            3,          // SHARE_READ | SHARE_WRITE
            null, 
            2,          // CREATE_ALWAYS
            128,        // FILE_ATTRIBUTE_NORMAL
            null
        );
        
        if ($this->ffi->cast("long long", $this->hFile)->cdata == -1) {
             Logger::error("Failed to create file Windows");
             return false;
        }
        
        $this->size = $initialSize;
        if ($initialSize > 0) {
            $this->hMap = $this->ffi->CreateFileMappingA(
                $this->hFile,
                null,
                0x04, // PAGE_READWRITE
                0, 
                $initialSize, 
                null
            );
            
            if ($this->hMap == null) {
                 Logger::error("Failed to create file mapping");
                 $this->ffi->CloseHandle($this->hFile);
                 return false;
            }
            
            $this->mappedAddr = $this->ffi->MapViewOfFile($this->hMap, 0x0002, 0, 0, 0); // FILE_MAP_WRITE
             if ($this->mappedAddr == null) {
                 Logger::error("Failed to map view");
                 $this->ffi->CloseHandle($this->hMap);
                 $this->ffi->CloseHandle($this->hFile);
                 return false;
             }
        }
        
        $this->_isOpen = true;
        Logger::debug("Created mmap file: {$this->path} with size: {$initialSize}");
        return true;
    }
    
    private function createPosix(int $initialSize): bool {
        // Flags: O_RDWR (2) | O_CREAT (64) | O_TRUNC (512) for Linux
        // Note: Constants vary by OS, checking mostly common values or using safer values if possible.
        // For simplicity assuming Linux/Mac common base or specific check:
        $flags = (PHP_OS_FAMILY === 'Darwin') ? 1538 : 578; 
        
        $this->fd = $this->ffi->open($this->path, $flags, 0644);
        if ($this->fd < 0) {
             Logger::error("Failed to create file POSIX");
             return false;
        }
        
        if ($initialSize > 0) {
            $this->ffi->ftruncate($this->fd, $initialSize);
            $this->size = $initialSize;
            $this->mapPosix();
        } else {
            $this->size = 0;
        }
        
        $this->_isOpen = true;
        Logger::debug("Created mmap file: {$this->path} with size: {$initialSize}");
        return true;
    }

    /**
     * Open an existing memory-mapped file.
     *
     * @param string $filePath Path to the file
     * @return bool True if successful
     */
    public function open(string $filePath): bool
    {
        $this->path = $filePath;
        if (!file_exists($filePath)) {
            Logger::error("File does not exist: {$filePath}");
            return false;
        }
        
        if ($this->ffi === null) return false;

        $this->size = filesize($filePath);
        
        if ($this->isWindows) {
            return $this->openWindows();
        } else {
            return $this->openPosix();
        }
    }
    
    private function openWindows(): bool {
        $this->hFile = $this->ffi->CreateFileA(
            $this->path, 
            0xC0000000, 
            3, 
            null, 
            4, // OPEN_ALWAYS
            128, 
            null
        );
        
        if ($this->ffi->cast("long long", $this->hFile)->cdata == -1) return false;
        
        if ($this->size > 0) {
            $this->hMap = $this->ffi->CreateFileMappingA($this->hFile, null, 0x04, 0, 0, null);
             if ($this->hMap != null) {
                 $this->mappedAddr = $this->ffi->MapViewOfFile($this->hMap, 0x0002, 0, 0, 0);
             }
        }
        
        $this->_isOpen = true;
        Logger::debug("Opened mmap file: {$this->path}");
        return true;
    }
    
    private function openPosix(): bool {
        $this->fd = $this->ffi->open($this->path, 2, 0); // O_RDWR
        if ($this->fd < 0) return false;
        
        if ($this->size > 0) {
            $this->mapPosix();
        }
        
        $this->_isOpen = true;
        Logger::debug("Opened mmap file: {$this->path}");
        return true;
    }
    
    private function mapPosix(): void {
        // PROT_READ | PROT_WRITE (3), MAP_SHARED (1)
        $this->mappedAddr = $this->ffi->mmap(null, $this->size, 3, 1, $this->fd, 0);
    }

    /**
     * Close the memory-mapped file.
     */
    public function close(): void
    {
        if (!$this->_isOpen) return;
        
        if ($this->isWindows) {
            if ($this->mappedAddr !== null) {
                $this->ffi->UnmapViewOfFile($this->mappedAddr);
                $this->mappedAddr = null;
            }
            if ($this->hMap !== null) {
                $this->ffi->CloseHandle($this->hMap);
                $this->hMap = null;
            }
            if ($this->hFile !== null) {
                $this->ffi->CloseHandle($this->hFile);
                $this->hFile = null;
            }
        } else {
            if ($this->mappedAddr !== null) {
                $this->ffi->munmap($this->mappedAddr, $this->size);
                 $this->mappedAddr = null;
            }
            if ($this->fd >= 0) {
                $this->ffi->close($this->fd);
                $this->fd = -1;
            }
        }
        $this->_isOpen = false;
    }

    /**
     * Write data to the file.
     *
     * @param int $offset Offset to write to
     * @param string $data Data to write
     * @return int Number of bytes written
     */
    public function write(int $offset, string $data): int
    {
        if (!$this->_isOpen) {
             $initialSize = $offset + strlen($data);
             if (!$this->create($this->path, $initialSize)) return 0;
        }
        
        $requiredSize = $offset + strlen($data);
        if ($requiredSize > $this->size) {
            if (!$this->resize($requiredSize)) {
                Logger::error('Failed to resize file for write operation');
                return 0;
            }
        }
        
        if ($this->mappedAddr === null) return 0;
        
        // Use FFI::memcpy to write to memory
        FFI::memcpy(
            $this->ffi->cast("char*", $this->mappedAddr) + $offset, 
            $data, 
            strlen($data)
        );
        
        return strlen($data);
    }

    /**
     * Read data from the file.
     *
     * @param int $offset Offset to read from
     * @param int $length Number of bytes to read
     * @return string Data read, or empty string on error
     */
    public function read(int $offset, int $length): string
    {
        if (!$this->_isOpen) {
            if (!$this->open($this->path)) return '';
        }

        if ($offset >= $this->size) {
            return '';
        }

        $actualLength = min($length, $this->size - $offset);
        if ($this->mappedAddr === null) return '';
        
        // Use FFI::string to read from memory
        return FFI::string(
            $this->ffi->cast("char*", $this->mappedAddr) + $offset, 
            $actualLength
        );
    }

    public function getSize(): int
    {
        return $this->size;
    }

    public function getPath(): string
    {
        return $this->path;
    }

    public function isOpen(): bool
    {
        return $this->_isOpen;
    }

    public function resize(int $newSize): bool
    {
        if (!$this->_isOpen) return false;

        if ($newSize === $this->size) return true;

        if ($this->isWindows) {
            // Unmap -> Resize File -> Remap
            if ($this->mappedAddr !== null) {
                $this->ffi->UnmapViewOfFile($this->mappedAddr);
                $this->mappedAddr = null;
            }
            if ($this->hMap !== null) {
                $this->ffi->CloseHandle($this->hMap);
                $this->hMap = null;
            }
            // SetFilePointer + SetEndOfFile
            $this->ffi->SetFilePointer($this->hFile, $newSize, null, 0);
            $this->ffi->SetEndOfFile($this->hFile);
            
            $this->size = $newSize;
            
            if ($newSize > 0) {
                $this->hMap = $this->ffi->CreateFileMappingA($this->hFile, null, 0x04, 0, $newSize, null);
                if ($this->hMap != null) {
                    $this->mappedAddr = $this->ffi->MapViewOfFile($this->hMap, 0x0002, 0, 0, 0);
                }
            }
        } else {
             // Unmap -> Ftruncate -> Remap
             if ($this->mappedAddr !== null) {
                 $this->ffi->munmap($this->mappedAddr, $this->size);
                 $this->mappedAddr = null;
             }
             $this->ffi->ftruncate($this->fd, $newSize);
             $this->size = $newSize;
             if ($this->size > 0) $this->mapPosix();
        }

        Logger::debug("Resized file {$this->path} to {$newSize} bytes");
        return true;
    }

    public function flush(): bool
    {
        if (!$this->_isOpen) return false;
        
        if ($this->isWindows) {
            if ($this->mappedAddr !== null) {
                $this->ffi->FlushViewOfFile($this->mappedAddr, 0);
            }
        } else {
            if ($this->mappedAddr !== null) {
                $this->ffi->msync($this->mappedAddr, $this->size, 4); // MS_SYNC
            }
        }
        
        Logger::debug("Flushed file: {$this->path}");
        return true;
    }

    public function finalize(int $finalSize): bool
    {
        if (!$this->_isOpen) return false;
        if (!$this->resize($finalSize)) return false;
        $this->flush();
        Logger::debug("Finalized file: {$this->path}");
        return true;
    }
}
