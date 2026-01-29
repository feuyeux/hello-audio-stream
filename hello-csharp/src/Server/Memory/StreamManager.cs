// Stream manager for managing active audio streams.
// Thread-safe registry of stream contexts.
// Matches Python StreamManager and Java StreamManager functionality.

using System;
using System.Collections.Concurrent;
using System.IO;
using System.Linq;

namespace AudioStreamServer.Memory;

/// <summary>
/// Stream manager for managing multiple concurrent streams.
/// </summary>
public class StreamManager
{
    private static StreamManager? _instance;
    private static readonly object _lock = new object();
    private readonly string _cacheDirectory;
    private readonly ConcurrentDictionary<string, StreamContext> _streams;

    /// <summary>
    /// Get the singleton instance of StreamManager.
    /// </summary>
    public static StreamManager GetInstance(string cacheDirectory = "cache")
    {
        if (_instance == null)
        {
            lock (_lock)
            {
                if (_instance == null)
                {
                    _instance = new StreamManager(cacheDirectory);
                }
            }
        }
        return _instance;
    }

    /// <summary>
    /// Private constructor for singleton pattern.
    /// </summary>
    private StreamManager(string cacheDirectory)
    {
        _cacheDirectory = cacheDirectory;
        _streams = new ConcurrentDictionary<string, StreamContext>();

        // Create cache directory if it doesn't exist
        if (!Directory.Exists(cacheDirectory))
        {
            Directory.CreateDirectory(cacheDirectory);
        }

        Logger.Instance.Info($"StreamManager initialized with cache directory: {cacheDirectory}");
    }

    /// <summary>
    /// Create a new stream.
    /// </summary>
    public bool CreateStream(string streamId)
    {
        // Check if stream already exists
        if (_streams.ContainsKey(streamId))
        {
            Logger.Instance.Warning($"Stream already exists: {streamId}");
            return false;
        }

        try
        {
            // Create new stream context
            string cachePath = GetCachePath(streamId);
            var context = new StreamContext(streamId, cachePath);
            context.Status = StreamStatus.Uploading;
            context.UpdateAccessTime();

            // Create memory-mapped cache file
            var mmapFile = new MemoryMappedCache(cachePath);
            if (!mmapFile.Create(cachePath, 0))
            {
                return false;
            }
            context.MmapFile = mmapFile;

            // Add to registry
            _streams[streamId] = context;

            Logger.Instance.Info($"Created stream: {streamId} at path: {cachePath}");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Failed to create stream {streamId}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// Get a stream context.
    /// </summary>
    public StreamContext? GetStream(string streamId)
    {
        if (_streams.TryGetValue(streamId, out var context))
        {
            context.UpdateAccessTime();
            return context;
        }
        return null;
    }

    /// <summary>
    /// Delete a stream.
    /// </summary>
    public bool DeleteStream(string streamId)
    {
        if (!_streams.TryRemove(streamId, out var context))
        {
            Logger.Instance.Warning($"Stream not found for deletion: {streamId}");
            return false;
        }

        try
        {
            // Close memory-mapped file
            context.MmapFile?.Close();

            // Remove cache file
            if (File.Exists(context.CachePath))
            {
                File.Delete(context.CachePath);
            }

            Logger.Instance.Info($"Deleted stream: {streamId}");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Failed to delete stream {streamId}: {ex.Message}");
            return false;
        }
    }

    /// <summary>
    /// List all active streams.
    /// </summary>
    public string[] ListActiveStreams()
    {
        return _streams.Keys.ToArray();
    }

    /// <summary>
    /// Write a chunk of data to a stream.
    /// </summary>
    public bool WriteChunk(string streamId, byte[] data)
    {
        var stream = GetStream(streamId);
        if (stream == null)
        {
            Logger.Instance.Error($"Stream not found for write: {streamId}");
            return false;
        }

        lock (stream.Lock)
        {
            if (stream.Status != StreamStatus.Uploading)
            {
                Logger.Instance.Error($"Stream {streamId} is not in uploading state");
                return false;
            }

            try
            {
                // Write data to memory-mapped file
                var mmapFile = stream.MmapFile;
                if (mmapFile == null)
                {
                    return false;
                }

                int written = mmapFile.Write(stream.CurrentOffset, data);

                if (written > 0)
                {
                    stream.CurrentOffset += written;
                    stream.TotalSize += written;
                    stream.UpdateAccessTime();

                    Logger.Instance.Debug($"Wrote {written} bytes to stream {streamId} at offset {stream.CurrentOffset - written}");
                    return true;
                }
                else
                {
                    Logger.Instance.Error($"Failed to write data to stream {streamId}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Error($"Error writing to stream {streamId}: {ex.Message}");
                return false;
            }
        }
    }

    /// <summary>
    /// Read a chunk of data from a stream.
    /// </summary>
    public byte[] ReadChunk(string streamId, long offset, int length)
    {
        var stream = GetStream(streamId);
        if (stream == null)
        {
            Logger.Instance.Error($"Stream not found for read: {streamId}");
            return Array.Empty<byte>();
        }

        lock (stream.Lock)
        {
            try
            {
                // Read data from memory-mapped file
                var mmapFile = stream.MmapFile;
                if (mmapFile == null)
                {
                    return Array.Empty<byte>();
                }

                byte[] data = mmapFile.Read(offset, length);
                stream.UpdateAccessTime();

                Logger.Instance.Debug($"Read {data.Length} bytes from stream {streamId} at offset {offset}");
                return data;
            }
            catch (Exception ex)
            {
                Logger.Instance.Error($"Error reading from stream {streamId}: {ex.Message}");
                return Array.Empty<byte>();
            }
        }
    }

    /// <summary>
    /// Finalize a stream.
    /// </summary>
    public bool FinalizeStream(string streamId)
    {
        var stream = GetStream(streamId);
        if (stream == null)
        {
            Logger.Instance.Error($"Stream not found for finalization: {streamId}");
            return false;
        }

        lock (stream.Lock)
        {
            if (stream.Status != StreamStatus.Uploading)
            {
                Logger.Instance.Warning($"Stream {streamId} is not in uploading state for finalization");
                return false;
            }

            try
            {
                // Finalize memory-mapped file
                var mmapFile = stream.MmapFile;
                if (mmapFile == null)
                {
                    return false;
                }

                if (mmapFile.Finalize(stream.TotalSize))
                {
                    stream.Status = StreamStatus.Ready;
                    stream.UpdateAccessTime();

                    Logger.Instance.Info($"Finalized stream: {streamId} with {stream.TotalSize} bytes");
                    return true;
                }
                else
                {
                    Logger.Instance.Error($"Failed to finalize memory-mapped file for stream {streamId}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.Error($"Error finalizing stream {streamId}: {ex.Message}");
                return false;
            }
        }
    }

    /// <summary>
    /// Clean up old streams (older than maxAgeHours).
    /// </summary>
    public void CleanupOldStreams(int maxAgeHours = 24)
    {
        DateTime now = DateTime.UtcNow;
        TimeSpan cutoff = TimeSpan.FromHours(maxAgeHours);

        var toRemove = _streams
            .Where(kvp => (now - kvp.Value.LastAccessedAt) > cutoff)
            .Select(kvp => kvp.Key)
            .ToList();

        foreach (string streamId in toRemove)
        {
            Logger.Instance.Info($"Cleaning up old stream: {streamId}");
            DeleteStream(streamId);
        }
    }

    /// <summary>
    /// Get cache file path for a stream.
    /// </summary>
    private string GetCachePath(string streamId)
    {
        return Path.Combine(_cacheDirectory, $"{streamId}.cache");
    }
}
