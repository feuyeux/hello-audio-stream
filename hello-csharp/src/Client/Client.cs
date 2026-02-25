using System.Diagnostics;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AudioStreamServer;

namespace AudioStreamClient;

/// <summary>Audio stream client — connects, uploads, downloads, verifies.</summary>
public sealed class Client : IDisposable
{
    private const int ChunkSize = 64 * 1024; // 64 KB

    private readonly string _uri;
    private ClientWebSocket? _ws;
    private string? _connId;

    public Client(string uri) { _uri = uri; }

    // ── Public API ──────────────────────────────────────────────────────

    public async Task ConnectAsync()
    {
        _ws = new ClientWebSocket();
        await _ws.ConnectAsync(new Uri(_uri), CancellationToken.None);

        var resp = await ReceiveJsonAsync();
        if (resp.Command != "CONNECTED") throw new Exception($"Expected CONNECTED, got {resp.Command}");
        _connId = resp.StreamId;
        Console.WriteLine($"Connected as {_connId}");
    }

    public async Task UploadAsync(string filePath, string streamId)
    {
        // CREATE
        await SendJsonAsync(new Message { Command = "CREATE", StreamId = streamId });
        var resp = await ReceiveJsonAsync();
        if (resp.Command != "CREATED") throw new Exception($"Expected CREATED, got {resp.Command}");
        Console.WriteLine($"Stream created: {streamId}");

        // Send binary data
        var fileSize = new FileInfo(filePath).Length;
        long sent = 0;
        var sw = Stopwatch.StartNew();
        using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read))
        {
            var buf = new byte[ChunkSize];
            int read;
            while ((read = await fs.ReadAsync(buf)) > 0)
            {
                await _ws!.SendAsync(new ArraySegment<byte>(buf, 0, read), WebSocketMessageType.Binary, true, CancellationToken.None);
                sent += read;
            }
        }
        sw.Stop();
        var mbps = fileSize * 8.0 / 1_000_000 / sw.Elapsed.TotalSeconds;
        Console.WriteLine($"Uploaded {sent} bytes in {sw.ElapsedMilliseconds} ms ({mbps:F1} Mbps)");

        // COMPLETE
        await SendJsonAsync(new Message { Command = "COMPLETE" });
        resp = await ReceiveJsonAsync();
        if (resp.Command != "COMPLETED") throw new Exception($"Expected COMPLETED, got {resp.Command}");
        Console.WriteLine($"Stream completed: {streamId}");
    }

    public async Task DownloadAsync(string streamId, string outputPath, long expectedSize)
    {
        var dir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);

        long received = 0;
        var sw = Stopwatch.StartNew();
        using (var fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write))
        {
            while (received < expectedSize)
            {
                var length = (int)Math.Min(ChunkSize, expectedSize - received);
                await SendJsonAsync(new Message { Command = "READ", StreamId = streamId, Offset = received, Length = length });

                var (type, data) = await ReceiveRawAsync();
                if (type == WebSocketMessageType.Text)
                {
                    var msg = JsonSerializer.Deserialize<Message>(Encoding.UTF8.GetString(data));
                    if (msg?.Command == "ERROR") throw new Exception($"Server error: {msg.Msg}");
                    throw new Exception($"Expected binary, got text: {msg?.Command}");
                }
                await fs.WriteAsync(data);
                received += data.Length;
            }
        }
        sw.Stop();
        var mbps = received * 8.0 / 1_000_000 / sw.Elapsed.TotalSeconds;
        Console.WriteLine($"Downloaded {received} bytes in {sw.ElapsedMilliseconds} ms ({mbps:F1} Mbps)");
    }

    public async Task CloseAsync()
    {
        if (_ws is { State: WebSocketState.Open })
        {
            try
            {
                await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None);
            }
            catch (WebSocketException) { /* server may close first */ }
            catch (IOException) { /* transport already closed */ }
        }
    }

    public void Dispose() => _ws?.Dispose();

    // ── Verification ────────────────────────────────────────────────────

    public static bool Verify(string original, string downloaded)
    {
        var origSize = new FileInfo(original).Length;
        var dlSize = new FileInfo(downloaded).Length;
        if (origSize != dlSize)
        {
            Console.Error.WriteLine($"Size mismatch: {origSize} vs {dlSize}");
            return false;
        }
        var h1 = Md5(original);
        var h2 = Md5(downloaded);
        if (h1 != h2)
        {
            Console.Error.WriteLine($"Checksum mismatch: {h1} vs {h2}");
            return false;
        }
        Console.WriteLine($"Verification passed (MD5: {h1})");
        return true;
    }

    // ── Internal ────────────────────────────────────────────────────────

    private async Task SendJsonAsync(Message m)
    {
        var bytes = Encoding.UTF8.GetBytes(m.ToJson());
        await _ws!.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
    }

    private async Task<Message> ReceiveJsonAsync()
    {
        var (_, data) = await ReceiveRawAsync();
        var json = Encoding.UTF8.GetString(data);
        return JsonSerializer.Deserialize<Message>(json)
               ?? throw new Exception("Failed to parse server response");
    }

    private async Task<(WebSocketMessageType type, byte[] data)> ReceiveRawAsync()
    {
        var buf = new byte[256 * 1024];
        var result = await _ws!.ReceiveAsync(new ArraySegment<byte>(buf), CancellationToken.None);
        var data = new byte[result.Count];
        Array.Copy(buf, data, result.Count);
        return (result.MessageType, data);
    }

    private static string Md5(string path)
    {
        using var md5 = System.Security.Cryptography.MD5.Create();
        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read);
        var hash = md5.ComputeHash(fs);
        return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
    }
}
