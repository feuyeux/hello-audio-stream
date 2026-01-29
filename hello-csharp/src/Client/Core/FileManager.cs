using System;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace AudioFileTransfer.Client.Core;

/// <summary>
/// File operations manager
/// </summary>
public static class FileManager
{
    private const int ChunkSize = 8192; // 8KB chunks to match server behavior

    public static async Task<long> GetFileSizeAsync(string path)
    {
        return await Task.Run(() => new FileInfo(path).Length);
    }

    public static async Task<byte[]> ReadChunkAsync(string path, long offset, int length)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        stream.Seek(offset, SeekOrigin.Begin);
        
        byte[] buffer = new byte[length];
        int bytesRead = await stream.ReadAsync(buffer, 0, length);
        
        if (bytesRead < length)
        {
            Array.Resize(ref buffer, bytesRead);
        }
        
        return buffer;
    }

    public static async Task WriteChunkAsync(string path, byte[] data)
    {
        string? directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
        }

        using var stream = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.None);
        await stream.WriteAsync(data, 0, data.Length);
    }

    public static async Task<string> ComputeSha256Async(string path)
    {
        using var sha256 = SHA256.Create();
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        
        byte[] hash = await sha256.ComputeHashAsync(stream);
        return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
    }
}
