using System.IO.MemoryMappedFiles;

namespace AudioStreamServer;

/// <summary>File-backed memory-mapped cache for a single stream.</summary>
public sealed class MmapCache : IDisposable
{
    private const long DefaultPageSize = 64L * 1024 * 1024;   // 64 MB
    private const long MaxCacheSize = 8L * 1024 * 1024 * 1024; // 8 GB

    private readonly string _path;
    private MemoryMappedFile? _mmf;
    private MemoryMappedViewAccessor? _accessor;
    private long _capacity;
    private bool _disposed;

    public MmapCache(string path)
    {
        _path = path;
    }

    /// <summary>Create the backing file and open the memory map.</summary>
    public void Create(long initialSize = 0)
    {
        var size = Math.Max(initialSize, DefaultPageSize);
        using (var fs = new FileStream(_path, FileMode.Create, FileAccess.ReadWrite, FileShare.ReadWrite))
        {
            fs.SetLength(size);
        }
        Open(size);
    }

    /// <summary>Write data at the given offset, growing the file if needed.</summary>
    public void Write(long offset, byte[] data)
    {
        var required = offset + data.Length;
        if (required > _capacity) Resize(required);
        _accessor!.WriteArray(offset, data, 0, data.Length);
    }

    /// <summary>Read data from the cache.</summary>
    public byte[] Read(long offset, int length)
    {
        EnsureOpen();
        var buf = new byte[length];
        _accessor!.ReadArray(offset, buf, 0, length);
        return buf;
    }

    /// <summary>Truncate the file to its final size and flush.</summary>
    public void Finalize(long finalSize)
    {
        Close();
        using (var fs = new FileStream(_path, FileMode.Open, FileAccess.ReadWrite))
        {
            fs.SetLength(finalSize);
        }
        Open(finalSize);
        _accessor!.Flush();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Close();
    }

    // ── Internal ────────────────────────────────────────────────────────

    private void Open(long size)
    {
        _mmf = MemoryMappedFile.CreateFromFile(_path, FileMode.Open, null, size, MemoryMappedFileAccess.ReadWrite);
        _accessor = _mmf.CreateViewAccessor(0, size, MemoryMappedFileAccess.ReadWrite);
        _capacity = size;
    }

    private void EnsureOpen()
    {
        if (_mmf != null) return;
        if (!File.Exists(_path)) throw new FileNotFoundException("Cache file not found", _path);
        var size = new FileInfo(_path).Length;
        Open(size);
    }

    private void Close()
    {
        _accessor?.Dispose();
        _accessor = null;
        _mmf?.Dispose();
        _mmf = null;
    }

    private void Resize(long required)
    {
        var newSize = _capacity;
        while (newSize < required) newSize = Math.Min(newSize * 2, MaxCacheSize);
        if (newSize > MaxCacheSize) throw new InvalidOperationException("Cache exceeds max size");
        Close();
        using (var fs = new FileStream(_path, FileMode.Open, FileAccess.ReadWrite))
        {
            fs.SetLength(newSize);
        }
        Open(newSize);
    }
}
