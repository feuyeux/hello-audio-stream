using System;
using System.Text.Json;
using System.Threading.Tasks;
using AudioFileTransfer.Client.Util;

namespace AudioFileTransfer.Client.Core;

/// <summary>
/// Upload manager for handling file uploads
/// </summary>
public static class UploadManager
{
    public static async Task<string> UploadAsync(WebSocketClient ws, string inputPath, long fileSize)
    {
        // Generate stream ID
        string streamId = StreamIdGenerator.Generate();
        
        Logger.Info($"Generated stream ID: {streamId}");

        // Send START message
        var startMessage = new ControlMessage
        {
            Type = "START",
            StreamId = streamId
        };
        string startJson = JsonSerializer.Serialize(startMessage);
        await ws.SendTextAsync(startJson);
        Logger.Debug("Sent START message");

        // Wait for STARTED response
        var response = await ws.ReceiveTextAsync();
        if (response == null || response.Type != "STARTED")
        {
            throw new Exception($"Failed to start stream: {response?.Message ?? "No response"}");
        }
        Logger.Debug("Received START_ACK");

        // Upload file in chunks
        long offset = 0;
        long lastProgress = 0;
        
        while (offset < fileSize)
        {
            int length = ChunkManager.CalculateChunkSize(fileSize, offset);
            byte[] chunk = await FileManager.ReadChunkAsync(inputPath, offset, length);
            
            await ws.SendBinaryAsync(chunk);
            
            offset += chunk.Length;
            
            // Report progress at 25%, 50%, 75%, 100%
            long progress = (offset * 100) / fileSize;
            if (progress >= lastProgress + 25 || offset == fileSize)
            {
                Logger.Info($"Upload progress: {offset}/{fileSize} bytes ({progress}%)");
                lastProgress = progress;
            }
        }

        // Send STOP message
        var stopMessage = new ControlMessage
        {
            Type = "STOP",
            StreamId = streamId
        };
        string stopJson = JsonSerializer.Serialize(stopMessage);
        await ws.SendTextAsync(stopJson);
        Logger.Debug("Sent STOP message");

        // Wait for STOPPED response
        response = await ws.ReceiveTextAsync();
        if (response == null || response.Type != "STOPPED")
        {
            throw new Exception($"Failed to stop stream: {response?.Message ?? "No response"}");
        }
        Logger.Debug("Received STOP_ACK");

        return streamId;
    }
}
