// Memory-mapped cache for efficient file I/O.
// Provides write, read, resize, and finalize operations.
// Matches Python MmapCache functionality.

using System;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Threading;

namespace AudioStreamServer.Memory;

/// <summary>
/// Memory-mapped cache implementation using System.IO.MemoryMappedFiles.
/// </summary>
public class MemoryMappedCache
{
    // Configuration constants - follows unified mmap specification v2.0.0
    private const long DefaultPageSize = 64L * 1024 * 1024; // 64MB
    private const long MaxCacheSize = 8L * 1024 * 1024 * 1024; // 8GB
    private const long SegmentSize = 1L * 1024 * 1024 * 1024; // 1GB per segment
    private const int BatchOperationLimit = 1000; // Max batch operations

    public string Path { get; }
    private MemoryMappedFile? _mmf;
    private MemoryMappedViewAccessor? _accessor;
    private long _size;
    private bool _isOpen;
    private readonly ReaderWriterLockSlim _rwLock = new ReaderWriterLockSlim();

    /// <summary>
    /// Create a new MemoryMappedCache.
    /// </summary>
    public MemoryMappedCache(string path)
    {
        Path = path;
        _mmf = null;
        _accessor = null;
        _size = 0;
        _isOpen = false;
    }

    /// <summary>
    /// Create a new memory-mapped file.
    /// </summary>
    public bool Create(string filePath, long initialSize = 0)
    {
        _rwLock.EnterWriteLock();
        try
        {
            return CreateInternal(filePath, initialSize);
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    private bool CreateInternal(string filePath, long initialSize)
    {
        try
        {
            // Remove existing file
            if (File.Exists(filePath))
            {
                File.Delete(filePath);
            }

            // Create file and set initial size
            using (var fs = new FileStream(filePath, FileMode.Create, FileAccess.ReadWrite, FileShare.ReadWrite))
            {
                if (initialSize > 0)
                {
                    fs.SetLength(initialSize);
                }
            }
            
            _size = initialSize;

            if (initialSize > 0)
            {
                // Create memory mapped file
                _mmf = MemoryMappedFile.CreateFromFile(
                    filePath,
                    FileMode.Open,
                    null, // mapName
                    initialSize,
                    MemoryMappedFileAccess.ReadWrite
                );

                // Create view accessor for the whole file (simplified for now, might need segmentation for very large files > 2GB on x86, but ok for x64)
                // Note: CreateViewAccessor(0, 0) maps the whole file
                _accessor = _mmf.CreateViewAccessor(0, 0, MemoryMappedFileAccess.ReadWrite);
            }
            else
            {
                _mmf = null;
                _accessor = null;
            }

            _isOpen = true;
            Logger.Instance.Debug($"Created mmap file: {filePath} with size: {initialSize}");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error creating mmap file {filePath}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Open an existing memory-mapped file.
    /// </summary>
    public bool Open(string filePath)
    {
        _rwLock.EnterWriteLock();
        try
        {
            return OpenInternal(filePath);
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    private bool OpenInternal(string filePath)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                Logger.Instance.Error($"File does not exist: {filePath}");
                return false;
            }

            var fileInfo = new FileInfo(filePath);
            _size = fileInfo.Length;

            if (_size > 0)
            {
                _mmf = MemoryMappedFile.CreateFromFile(
                    filePath,
                    FileMode.Open,
                    null,
                    _size, // 0 to map full file capacity? No, needs actual capacity if larger?
                           // CreateFromFile with capacity 0 uses file stream length.
                           // But here we specify capacity explicitly to be safe or 0 for current size.
                    MemoryMappedFileAccess.ReadWrite
                );

                _accessor = _mmf.CreateViewAccessor(0, 0, MemoryMappedFileAccess.ReadWrite);
            }

            _isOpen = true;
            Logger.Instance.Debug($"Opened mmap file: {filePath} with size: {_size}");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error opening mmap file {filePath}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Close the memory-mapped file.
    /// </summary>
    public void Close()
    {
        _rwLock.EnterWriteLock();
        try
        {
            CloseInternal();
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    private void CloseInternal()
    {
        if (_isOpen)
        {
            _accessor?.Dispose();
            _accessor = null;
            _mmf?.Dispose();
            _mmf = null;
            _isOpen = false;
        }
    }

    /// <summary>
    /// Write data to the file.
    /// </summary>
    public int Write(long offset, byte[] data)
    {
        _rwLock.EnterWriteLock();
        try
        {
            if (!_isOpen)
            {
                long initialSize = offset + data.Length;
                if (!CreateInternal(Path, initialSize))
                {
                    return 0;
                }
            }

            long requiredSize = offset + data.Length;
            if (requiredSize > _size)
            {
                if (!ResizeInternal(requiredSize))
                {
                    Logger.Instance.Error("Failed to resize file for write operation");
                    return 0;
                }
            }

            if (_accessor == null)
            {
                 Logger.Instance.Error("Accessor is null after resize/create");
                 return 0;
            }

            // Write data using accessor
            _accessor.WriteArray(offset, data, 0, data.Length);
            return data.Length;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error writing to file {Path}: {ex.Message}");
            return 0;
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    /// <summary>
    /// Read data from the file.
    /// </summary>
    public byte[] Read(long offset, int length)
    {
        _rwLock.EnterReadLock();
        try
        {
            // Auto open logic handled with lock upgrade pattern in Go, here simplifed:
            if (!_isOpen)
            {
                _rwLock.ExitReadLock();
                _rwLock.EnterWriteLock();
                try 
                {
                    if (!_isOpen)
                    {
                        if (!OpenInternal(Path))
                        {
                            return Array.Empty<byte>();
                        }
                    }
                }
                finally
                {
                     _rwLock.ExitWriteLock();
                }
                _rwLock.EnterReadLock();
            }

            if (offset >= _size)
            {
                return Array.Empty<byte>();
            }
            
            if (_accessor == null)
            {
                // Can happen if size is 0
                return Array.Empty<byte>();
            }

            int actualLength = Math.Min(length, (int)(_size - offset));
            byte[] buffer = new byte[actualLength];
            
            _accessor.ReadArray(offset, buffer, 0, actualLength);

            Logger.Instance.Debug($"Read {actualLength} bytes from {Path} at offset {offset}");
            return buffer;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error reading from file {Path}: {ex.Message}");
            return Array.Empty<byte>();
        }
        finally
        {
            _rwLock.ExitReadLock();
        }
    }

    /// <summary>
    /// Get the size of the file.
    /// </summary>
    public long GetSize()
    {
        _rwLock.EnterReadLock();
        try
        {
            return _size;
        }
        finally
        {
            _rwLock.ExitReadLock();
        }
    }

    /// <summary>
    /// Check if the file is open.
    /// </summary>
    public bool IsOpen()
    {
        _rwLock.EnterReadLock();
        try
        {
            return _isOpen;
        }
        finally
        {
            _rwLock.ExitReadLock();
        }
    }

    /// <summary>
    /// Resize the file to a new size.
    /// </summary>
    public bool Resize(long newSize)
    {
        _rwLock.EnterWriteLock();
        try
        {
            return ResizeInternal(newSize);
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    /// <summary>
    /// Resize the file to a new size (internal, no lock).
    /// </summary>
    private bool ResizeInternal(long newSize)
    {
        if (!_isOpen)
        {
            Logger.Instance.Error($"File not open for resize: {Path}");
            return false;
        }

        if (newSize == _size)
        {
            return true;
        }

        try
        {
            // Must dispose MMF before resizing file
            _accessor?.Dispose();
            _accessor = null;
            _mmf?.Dispose();
            _mmf = null;

            // Resize file stream equivalent
            // Create a temporary stream to resize
            using (var fs = new FileStream(Path, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite))
            {
                fs.SetLength(newSize);
            }
            
            _size = newSize;

            // Re-create MMF
            if (newSize > 0)
            {
                _mmf = MemoryMappedFile.CreateFromFile(
                    Path,
                    FileMode.Open,
                    null,
                    newSize,
                    MemoryMappedFileAccess.ReadWrite
                );
                _accessor = _mmf.CreateViewAccessor(0, 0, MemoryMappedFileAccess.ReadWrite);
            }

            Logger.Instance.Debug($"Resized file {Path} to {newSize} bytes");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error resizing file {Path}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Flush all data to disk.
    /// </summary>
    public bool Flush()
    {
        _rwLock.EnterWriteLock();
        try
        {
            if (!_isOpen)
            {
                Logger.Instance.Warning($"File not open for flush: {Path}");
                return false;
            }

            _accessor?.Flush();
            Logger.Instance.Debug($"Flushed file: {Path}");
            return true;
        }
        catch (Exception ex)
        {
             Logger.Instance.Error($"Error flushing file {Path}: {ex.Message}");
             return false;
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }

    /// <summary>
    /// Finalize the file to its final size.
    /// </summary>
    public bool Finalize(long finalSize)
    {
        _rwLock.EnterWriteLock();
        try
        {
            if (!_isOpen)
            {
                Logger.Instance.Warning($"File not open for finalization: {Path}");
                return false;
            }

            if (!ResizeInternal(finalSize))
            {
                Logger.Instance.Error($"Failed to resize file during finalization: {Path}");
                return false;
            }

            _accessor?.Flush();

            Logger.Instance.Debug($"Finalized file: {Path} with size: {finalSize}");
            return true;
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }
}
