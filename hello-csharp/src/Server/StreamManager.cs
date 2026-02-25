namespace AudioStreamServer;

/// <summary>Stream lifecycle status.</summary>
public enum StreamStatus { Uploading, Ready, Error }

/// <summary>Manages all active streams and their caches.</summary>
public sealed class StreamManager
{
    public const int MaxStreams = 1000;
    private static readonly TimeSpan MaxIdleTime = TimeSpan.FromHours(24);
    private static readonly TimeSpan MaxUploadingTime = TimeSpan.FromHours(1);

    private readonly string _cacheDir;
    private readonly Dictionary<string, Stream> _streams = new();
    private readonly object _lock = new();

    public StreamManager(string cacheDir = "audio/output")
    {
        _cacheDir = cacheDir;
        Directory.CreateDirectory(cacheDir);
    }

    public void Create(string streamId)
    {
        lock (_lock)
        {
            if (_streams.Count >= MaxStreams)
                throw new InvalidOperationException($"Max streams ({MaxStreams}) reached");
            if (_streams.ContainsKey(streamId))
                throw new InvalidOperationException($"Stream already exists: {streamId}");

            var cache = new MmapCache(Path.Combine(_cacheDir, $"{streamId}.cache"));
            cache.Create();
            _streams[streamId] = new Stream(streamId, cache);
        }
    }

    public void Write(string streamId, byte[] data)
    {
        var stream = GetStream(streamId);
        lock (stream.Lock)
        {
            stream.Cache.Write(stream.Offset, data);
            stream.Offset += data.Length;
            stream.LastAccess = DateTime.UtcNow;
        }
    }

    public void Complete(string streamId)
    {
        var stream = GetStream(streamId);
        lock (stream.Lock)
        {
            stream.Cache.Finalize(stream.Offset);
            stream.Status = StreamStatus.Ready;
            stream.LastAccess = DateTime.UtcNow;
        }
    }

    public byte[] Read(string streamId, long offset, int length)
    {
        var stream = GetStream(streamId);
        lock (stream.Lock)
        {
            stream.LastAccess = DateTime.UtcNow;
            return stream.Cache.Read(offset, length);
        }
    }

    public void Delete(string streamId)
    {
        lock (_lock)
        {
            if (_streams.Remove(streamId, out var stream))
            {
                stream.Cache.Dispose();
            }
        }
    }

    public void MarkError(string streamId)
    {
        lock (_lock)
        {
            if (_streams.TryGetValue(streamId, out var stream))
                stream.Status = StreamStatus.Error;
        }
    }

    public (StreamStatus status, long size) StatusOf(string streamId)
    {
        var stream = GetStream(streamId);
        lock (stream.Lock)
        {
            return (stream.Status, stream.Offset);
        }
    }

    public string[] List()
    {
        lock (_lock)
        {
            return _streams.Keys.ToArray();
        }
    }

    public int Cleanup()
    {
        lock (_lock)
        {
            var now = DateTime.UtcNow;
            var toRemove = _streams.Where(kv =>
            {
                var s = kv.Value;
                var idle = now - s.LastAccess;
                return idle > MaxIdleTime
                    || (s.Status == StreamStatus.Uploading && idle > MaxUploadingTime)
                    || s.Status == StreamStatus.Error;
            }).Select(kv => kv.Key).ToList();

            foreach (var id in toRemove)
            {
                if (_streams.Remove(id, out var stream))
                    stream.Cache.Dispose();
            }
            return toRemove.Count;
        }
    }

    public (int total, int uploading, int ready, int error) Stats()
    {
        lock (_lock)
        {
            int u = 0, r = 0, e = 0;
            foreach (var s in _streams.Values)
            {
                switch (s.Status)
                {
                    case StreamStatus.Uploading: u++; break;
                    case StreamStatus.Ready: r++; break;
                    case StreamStatus.Error: e++; break;
                }
            }
            return (_streams.Count, u, r, e);
        }
    }

    // ── Internal ────────────────────────────────────────────────────────

    private Stream GetStream(string streamId)
    {
        lock (_lock)
        {
            return _streams.TryGetValue(streamId, out var s)
                ? s
                : throw new KeyNotFoundException($"Stream not found: {streamId}");
        }
    }

    /// <summary>Internal stream state.</summary>
    internal sealed class Stream
    {
        public string Id { get; }
        public MmapCache Cache { get; }
        public long Offset { get; set; }
        public DateTime Created { get; }
        public DateTime LastAccess { get; set; }
        public StreamStatus Status { get; set; }
        public object Lock { get; } = new();

        public Stream(string id, MmapCache cache)
        {
            Id = id;
            Cache = cache;
            Created = DateTime.UtcNow;
            LastAccess = DateTime.UtcNow;
            Status = StreamStatus.Uploading;
        }
    }
}
