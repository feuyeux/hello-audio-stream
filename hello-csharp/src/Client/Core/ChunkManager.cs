using System;

namespace AudioFileTransfer.Client.Core;

/// <summary>
/// Chunk manager for handling file chunking operations
/// </summary>
public static class ChunkManager
{
    public const int ChunkSize = 8192; // 8KB chunks to match server behavior

    /// <summary>
    /// Calculate the number of chunks needed for a file
    /// </summary>
    public static int CalculateChunkCount(long fileSize)
    {
        return (int)Math.Ceiling((double)fileSize / ChunkSize);
    }

    /// <summary>
    /// Calculate the size of a specific chunk
    /// </summary>
    public static int CalculateChunkSize(long fileSize, long offset)
    {
        return (int)Math.Min(ChunkSize, fileSize - offset);
    }

    /// <summary>
    /// Validate chunk parameters
    /// </summary>
    public static void ValidateChunk(long fileSize, long offset, int length)
    {
        if (offset < 0)
        {
            throw new ArgumentException("Offset cannot be negative", nameof(offset));
        }

        if (length <= 0)
        {
            throw new ArgumentException("Length must be positive", nameof(length));
        }

        if (offset >= fileSize)
        {
            throw new ArgumentException("Offset exceeds file size", nameof(offset));
        }

        if (offset + length > fileSize)
        {
            throw new ArgumentException("Chunk extends beyond file size");
        }
    }
}
