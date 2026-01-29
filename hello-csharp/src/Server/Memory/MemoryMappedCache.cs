// Memory-mapped cache for efficient file I/O.
// Provides write, read, resize, and finalize operations.
// Matches Python MmapCache functionality.

using System;
using System.IO;
using System.Linq;
using System.Threading;

namespace AudioStreamServer.Memory;

/// <summary>
/// Memory-mapped cache implementation.
/// </summary>
public class MemoryMappedCache
{
    // Configuration constants - follows unified mmap specification v2.0.0
    private const long DefaultPageSize = 64L * 1024 * 1024; // 64MB
    private const long MaxCacheSize = 8L * 1024 * 1024 * 1024; // 8GB
    private const long SegmentSize = 1L * 1024 * 1024 * 1024; // 1GB per segment
    private const int BatchOperationLimit = 1000; // Max batch operations

    public string Path { get; }
    private FileStream? _fileStream;
    private long _size;
    private bool _isOpen;
    private readonly ReaderWriterLockSlim _rwLock = new ReaderWriterLockSlim();

    /// <summary>
    /// Create a new MemoryMappedCache.
    /// </summary>
    public MemoryMappedCache(string path)
    {
        Path = path;
        _fileStream = null;
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
        // Remove existing file
        if (File.Exists(filePath))
        {
            File.Delete(filePath);
        }

        // Create and open file
        _fileStream = new FileStream(
            filePath,
            FileMode.Create,
            FileAccess.ReadWrite,
            FileShare.ReadWrite
        );

        if (initialSize > 0)
        {
            // Write zeros to allocate space
            _fileStream.SetLength(initialSize);
            _size = initialSize;
        }
        else
        {
            _size = 0;
        }

        _isOpen = true;
        Logger.Instance.Debug($"Created mmap file: {filePath} with size: {initialSize}");
        return true;
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
        if (!File.Exists(filePath))
        {
            Logger.Instance.Error($"File does not exist: {filePath}");
            return false;
        }

        _fileStream = new FileStream(
            filePath,
            FileMode.Open,
            FileAccess.ReadWrite,
            FileShare.ReadWrite
        );

        _size = _fileStream.Length;
        _isOpen = true;
        Logger.Instance.Debug($"Opened mmap file: {filePath} with size: {_size}");
        return true;
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
        if (_isOpen && _fileStream != null)
        {
            _fileStream.Close();
            _fileStream = null;
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
            if (!_isOpen || _fileStream == null)
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

            // Seek to offset
            _fileStream!.Seek(offset, SeekOrigin.Begin);

            // Write data
            _fileStream.Write(data, 0, data.Length);
            return data.Length;
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
            if (!_isOpen || _fileStream == null)
            {
                _rwLock.ExitReadLock();
                _rwLock.EnterWriteLock();
                try
                {
                    if (!_isOpen || _fileStream == null)
                    {
                        if (!OpenInternal(Path))
                        {
                            Logger.Instance.Error($"Failed to open file for reading: {Path}");
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

            // Seek to offset
            _fileStream!.Seek(offset, SeekOrigin.Begin);

            // Read data
            int actualLength = Math.Min(length, (int)(_size - offset));
            byte[] buffer = new byte[actualLength];
            int bytesRead = _fileStream.Read(buffer, 0, actualLength);

            Logger.Instance.Debug($"Read {bytesRead} bytes from {Path} at offset {offset}");
            return buffer.Take(bytesRead).ToArray();
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

        if (newSize < _size)
        {
            // Truncate
            Logger.Instance.Warning($"Truncating file {Path} to {newSize}");
        }

        _fileStream!.SetLength(newSize);
        _size = newSize;
        Logger.Instance.Debug($"Resized file {Path} to {newSize} bytes");
        return true;
    }

    /// <summary>
    /// Flush all data to disk.
    /// </summary>
    public bool Flush()
    {
        _rwLock.EnterWriteLock();
        try
        {
            if (!_isOpen || _fileStream == null)
            {
                Logger.Instance.Warning($"File not open for flush: {Path}");
                return false;
            }

            _fileStream.Flush();
            Logger.Instance.Debug($"Flushed file: {Path}");
            return true;
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

            // Flush to disk
            _fileStream!.Flush();

            Logger.Instance.Debug($"Finalized file: {Path} with size: {finalSize}");
            return true;
        }
        finally
        {
            _rwLock.ExitWriteLock();
        }
    }
}
