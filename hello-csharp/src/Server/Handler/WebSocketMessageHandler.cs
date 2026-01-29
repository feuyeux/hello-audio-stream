using System.Text.Json.Serialization;

namespace AudioStreamServer.Handler;

/// <summary>
/// WebSocket message types
/// </summary>
public class WebSocketMessage
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("streamId")]
    public string? StreamId { get; set; }

    [JsonPropertyName("offset")]
    public long? Offset { get; set; }

    [JsonPropertyName("length")]
    public int? Length { get; set; }

    [JsonPropertyName("message")]
    public string? Message { get; set; }
}
