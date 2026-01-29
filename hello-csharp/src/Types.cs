using System.Text.Json.Serialization;

namespace AudioFileTransfer;

/// <summary>
/// Configuration for the audio client
/// </summary>
public class Config
{
    public required string InputPath { get; set; }
    public required string OutputPath { get; set; }
    public required string ServerUri { get; set; }
    public bool Verbose { get; set; }
}

/// <summary>
/// Control message types
/// </summary>
public enum MessageType
{
    Start,
    Stop,
    Get,
    Started,
    Stopped,
    Error
}

/// <summary>
/// Control message for WebSocket communication
/// </summary>
public class ControlMessage
{
    [JsonPropertyName("type")]
    public required string Type { get; set; }
    
    [JsonPropertyName("streamId")]
    public string? StreamId { get; set; }
    
    [JsonPropertyName("offset")]
    public long? Offset { get; set; }
    
    [JsonPropertyName("length")]
    public int? Length { get; set; }
    
    [JsonPropertyName("message")]
    public string? Message { get; set; }
}

/// <summary>
/// Verification result
/// </summary>
public class VerificationResult
{
    public bool Passed { get; set; }
    public long OriginalSize { get; set; }
    public long DownloadedSize { get; set; }
    public required string OriginalChecksum { get; set; }
    public required string DownloadedChecksum { get; set; }
}

/// <summary>
/// Performance report
/// </summary>
public class PerformanceReport
{
    public long UploadDurationMs { get; set; }
    public double UploadThroughputMbps { get; set; }
    public long DownloadDurationMs { get; set; }
    public double DownloadThroughputMbps { get; set; }
    public long TotalDurationMs { get; set; }
    public double AverageThroughputMbps { get; set; }
}
