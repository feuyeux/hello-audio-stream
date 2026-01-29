// Stream context for managing active audio streams.
// Contains stream metadata and cache file handle.
// Matches Python StreamContext and Java StreamContext functionality.

using System;
using System.Threading;

namespace AudioStreamServer.Memory;

/// <summary>
/// Stream status enumeration
/// </summary>
public enum StreamStatus
{
    Uploading,
    Ready,
    Error
}

/// <summary>
/// Stream context containing metadata and state for a single stream.
/// </summary>
public class StreamContext
{
    public string StreamId { get; private set; }
    public string CachePath { get; set; }
    public MemoryMappedCache? MmapFile { get; set; }
    public long CurrentOffset { get; set; }
    public long TotalSize { get; set; }
    public DateTime CreatedAt { get; private set; }
    public DateTime LastAccessedAt { get; private set; }
    public StreamStatus Status { get; set; }
    
    /// <summary>
    /// Lock object for thread-safe access to this stream context
    /// </summary>
    public object Lock { get; } = new object();

    /// <summary>
    /// Create a new StreamContext.
    /// </summary>
    public StreamContext(string streamId, string cachePath = "")
    {
        StreamId = streamId;
        CachePath = cachePath;
        MmapFile = null;
        CurrentOffset = 0;
        TotalSize = 0;
        var now = DateTime.UtcNow;
        CreatedAt = now;
        LastAccessedAt = now;
        Status = StreamStatus.Uploading;
    }

    /// <summary>
    /// Update last accessed timestamp
    /// </summary>
    public void UpdateAccessTime()
    {
        LastAccessedAt = DateTime.UtcNow;
    }
}
