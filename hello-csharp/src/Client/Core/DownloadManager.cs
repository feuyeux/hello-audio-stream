using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace AudioFileTransfer.Client.Core;

/// <summary>
/// Download manager for handling file downloads
/// </summary>
public static class DownloadManager
{
    public static async Task DownloadAsync(WebSocketClient ws, string streamId, string outputPath, long fileSize)
    {
        // Ensure output directory exists
        string? directory = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
        }

        // Delete output file if it exists
        if (File.Exists(outputPath))
        {
            File.Delete(outputPath);
        }

        long offset = 0;
        long lastProgress = 0;

        while (offset < fileSize)
        {
            int length = ChunkManager.CalculateChunkSize(fileSize, offset);
            
            // Send GET message
            var getMessage = new ControlMessage
            {
                Type = "GET",
                StreamId = streamId,
                Offset = offset,
                Length = length
            };
            string getJson = JsonSerializer.Serialize(getMessage);
            await ws.SendTextAsync(getJson);
            Logger.Debug($"Requesting chunk at offset {offset}, length {length}");

            // Receive binary data
            byte[] data = await ws.ReceiveBinaryAsync();
            Logger.Debug($"Received {data.Length} bytes of data");

            // Write to file
            await FileManager.WriteChunkAsync(outputPath, data);

            offset += data.Length;

            // Report progress at 25%, 50%, 75%, 100%
            long progress = (offset * 100) / fileSize;
            if (progress >= lastProgress + 25 || offset == fileSize)
            {
                Logger.Info($"Download progress: {offset}/{fileSize} bytes ({progress}%)");
                lastProgress = progress;
            }
        }

        Logger.Info($"Download completed: {outputPath}");
    }
}
