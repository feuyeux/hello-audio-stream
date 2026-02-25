using System.Text.Json;
using System.Text.Json.Serialization;

namespace AudioStreamServer;

/// <summary>JSON message DTO for WebSocket communication.</summary>
public class Message
{
    [JsonPropertyName("command")]
    public string Command { get; set; } = "";

    [JsonPropertyName("streamId")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? StreamId { get; set; }

    [JsonPropertyName("offset")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? Offset { get; set; }

    [JsonPropertyName("length")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Length { get; set; }

    [JsonPropertyName("message")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Msg { get; set; }

    [JsonPropertyName("status")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Status { get; set; }

    [JsonPropertyName("size")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public long? Size { get; set; }

    [JsonPropertyName("streams")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Streams { get; set; }

    // ── Factory methods ─────────────────────────────────────────────────

    public static Message Connected(string connId) => new() { Command = "CONNECTED", StreamId = connId };
    public static Message Created(string streamId) => new() { Command = "CREATED", StreamId = streamId };
    public static Message Completed(string streamId) => new() { Command = "COMPLETED", StreamId = streamId };
    public static Message Closed(string streamId) => new() { Command = "CLOSED", StreamId = streamId };
    public static Message Error(string message) => new() { Command = "ERROR", Msg = message };

    public static Message StreamStatus(string streamId, string status, long size) =>
        new() { Command = "STATUS", StreamId = streamId, Status = status, Size = size };

    public static Message StreamList(IEnumerable<string> ids) =>
        new() { Command = "STREAM_LIST", Streams = string.Join(",", ids) };

    // ── Parse ───────────────────────────────────────────────────────────

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public static (Message msg, CommandInfo info) Parse(string json)
    {
        var m = JsonSerializer.Deserialize<Message>(json, JsonOpts)
                ?? throw new ArgumentException("Invalid JSON");
        var info = CommandInfo.Lookup(m.Command);
        return (m, info);
    }

    public string ToJson() => JsonSerializer.Serialize(this, JsonOpts);
}
