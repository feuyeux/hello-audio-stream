// Memory pool manager for efficient buffer reuse.
// Pre-allocates buffers to minimize allocation overhead.
// Implemented as a singleton to ensure a single shared pool across all streams.
// Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.

using System;
using System.Collections.Concurrent;

namespace AudioStreamServer.Memory;

/// <summary>
/// Memory pool manager singleton.
/// </summary>
public class MemoryPoolManager
{
    private static MemoryPoolManager? _instance;
    private static readonly object _lock = new object();
    private readonly int _bufferSize;
    private readonly int _poolSize;
    private readonly ConcurrentQueue<byte[]> _availableBuffers;
    private int _totalBuffers;

    /// <summary>
    /// Get the singleton instance of MemoryPoolManager.
    /// </summary>
    public static MemoryPoolManager GetInstance(int bufferSize = 65536, int poolSize = 100)
    {
        if (_instance == null)
        {
            lock (_lock)
            {
                if (_instance == null)
                {
                    _instance = new MemoryPoolManager(bufferSize, poolSize);
                }
            }
        }
        return _instance;
    }

    /// <summary>
    /// Private constructor for singleton pattern.
    /// </summary>
    private MemoryPoolManager(int bufferSize, int poolSize)
    {
        _bufferSize = bufferSize;
        _poolSize = poolSize;
        _availableBuffers = new ConcurrentQueue<byte[]>();
        _totalBuffers = 0;

        // Pre-allocate buffers
        for (int i = 0; i < poolSize; i++)
        {
            byte[] buffer = new byte[bufferSize];
            _availableBuffers.Enqueue(buffer);
            _totalBuffers++;
        }

        Logger.Instance.Info($"MemoryPoolManager initialized with {poolSize} buffers of {bufferSize} bytes");
    }

    /// <summary>
    /// Acquire a buffer from the pool.
    /// If pool is exhausted, allocates a new buffer dynamically.
    /// </summary>
    public byte[] AcquireBuffer()
    {
        if (_availableBuffers.TryDequeue(out byte[]? buffer))
        {
            Logger.Instance.Debug($"Acquired buffer from pool ({_availableBuffers.Count} remaining)");
            return buffer!;
        }
        else
        {
            // Pool exhausted, allocate new buffer
            byte[] newBuffer = new byte[_bufferSize];
            _totalBuffers++;
            Logger.Instance.Debug($"Pool exhausted, allocated new buffer (total: {_totalBuffers})");
            return newBuffer;
        }
    }

    /// <summary>
    /// Release a buffer back to the pool.
    /// </summary>
    public void ReleaseBuffer(byte[] buffer)
    {
        if (buffer.Length != _bufferSize)
        {
            Logger.Instance.Warning($"Buffer size mismatch: expected {_bufferSize}, got {buffer.Length}");
            return;
        }

        // Clear buffer before returning to pool
        Array.Clear(buffer, 0, buffer.Length);

        // Only return to pool if we haven't exceeded pool size
        if (_availableBuffers.Count < _poolSize)
        {
            _availableBuffers.Enqueue(buffer);
        }

        Logger.Instance.Debug($"Released buffer to pool ({_availableBuffers.Count} available)");
    }

    /// <summary>
    /// Get the number of available buffers in the pool.
    /// </summary>
    public int GetAvailableBuffers()
    {
        return _availableBuffers.Count;
    }

    /// <summary>
    /// Get the total number of buffers (available + in-use).
    /// </summary>
    public int GetTotalBuffers()
    {
        return _poolSize;
    }

    /// <summary>
    /// Get the buffer size.
    /// </summary>
    public int GetBufferSize()
    {
        return _bufferSize;
    }
}
