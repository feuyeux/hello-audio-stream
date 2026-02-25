using System.Net.WebSockets;
using System.Text;

namespace AudioStreamServer;

/// <summary>Per-connection WebSocket handler.</summary>
public sealed class Handler
{
    private readonly StreamManager _mgr;
    private readonly string _connId;
    private readonly WebSocket _ws;
    private string? _streamId;

    public Handler(StreamManager mgr, string connId, WebSocket ws)
    {
        _mgr = mgr;
        _connId = connId;
        _ws = ws;
    }

    /// <summary>Main message loop — call once per connection.</summary>
    public async Task RunAsync(CancellationToken ct)
    {
        await SendAsync(Message.Connected(_connId), ct);
        var buffer = new byte[256 * 1024]; // 256 KB receive buffer

        try
        {
            while (_ws.State == WebSocketState.Open)
            {
                var result = await _ws.ReceiveAsync(new ArraySegment<byte>(buffer), ct);
                if (result.MessageType == WebSocketMessageType.Close) break;

                if (result.MessageType == WebSocketMessageType.Binary)
                {
                    var data = new byte[result.Count];
                    Array.Copy(buffer, data, result.Count);
                    await HandleBinaryAsync(data, ct);
                }
                else
                {
                    var text = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    await HandleTextAsync(text, ct);
                }
            }
        }
        finally
        {
            OnClose();
        }
    }

    private void OnClose()
    {
        if (_streamId != null)
        {
            try { _mgr.MarkError(_streamId); } catch { /* ignore */ }
        }
        Console.WriteLine($"[{_connId}] disconnected");
    }

    // ── Dispatch ────────────────────────────────────────────────────────

    private async Task HandleTextAsync(string text, CancellationToken ct)
    {
        try
        {
            var (m, info) = Message.Parse(text);
            switch (info.CmdType)
            {
                case CommandType.Stream:
                    await HandleStreamCmdAsync(info.StreamCmd!.Value, m, ct);
                    break;
                case CommandType.Data:
                    await HandleDataCmdAsync(m, ct);
                    break;
                case CommandType.Query:
                    await HandleQueryCmdAsync(info.QueryCmd!.Value, m, ct);
                    break;
            }
        }
        catch (Exception e)
        {
            await SendErrorAsync(e.Message, ct);
        }
    }

    private async Task HandleBinaryAsync(byte[] data, CancellationToken ct)
    {
        if (_streamId == null)
        {
            await SendErrorAsync("No active upload stream", ct);
            return;
        }
        try { _mgr.Write(_streamId, data); }
        catch (Exception e) { await SendErrorAsync(e.Message, ct); }
    }

    // ── Stream commands ─────────────────────────────────────────────────

    private async Task HandleStreamCmdAsync(StreamCommand cmd, Message m, CancellationToken ct)
    {
        try
        {
            switch (cmd)
            {
                case StreamCommand.Create:
                    var streamId = m.StreamId ?? throw new ArgumentException("CREATE requires streamId");
                    _mgr.Create(streamId);
                    _streamId = streamId;
                    await SendAsync(Message.Created(streamId), ct);
                    break;

                case StreamCommand.Complete:
                    if (_streamId == null) throw new InvalidOperationException("No active stream");
                    var sid = _streamId;
                    _mgr.Complete(sid);
                    _streamId = null;
                    await SendAsync(Message.Completed(sid), ct);
                    break;

                case StreamCommand.Close:
                    var closeId = m.StreamId ?? throw new ArgumentException("CLOSE requires streamId");
                    _mgr.Delete(closeId);
                    await SendAsync(Message.Closed(closeId), ct);
                    break;
            }
        }
        catch (Exception e) { await SendErrorAsync(e.Message, ct); }
    }

    // ── Data commands ───────────────────────────────────────────────────

    private async Task HandleDataCmdAsync(Message m, CancellationToken ct)
    {
        try
        {
            var streamId = m.StreamId ?? throw new ArgumentException("READ requires streamId");
            var offset = m.Offset ?? 0;
            var length = m.Length ?? 65536;
            var data = _mgr.Read(streamId, offset, length);
            if (data.Length > 0)
                await _ws.SendAsync(new ArraySegment<byte>(data), WebSocketMessageType.Binary, true, ct);
            else
                await SendErrorAsync("No data at requested offset", ct);
        }
        catch (Exception e) { await SendErrorAsync(e.Message, ct); }
    }

    // ── Query commands ──────────────────────────────────────────────────

    private async Task HandleQueryCmdAsync(QueryCommand cmd, Message m, CancellationToken ct)
    {
        try
        {
            switch (cmd)
            {
                case QueryCommand.GetStatus:
                    var streamId = m.StreamId ?? throw new ArgumentException("GET_STATUS requires streamId");
                    var (status, size) = _mgr.StatusOf(streamId);
                    await SendAsync(Message.StreamStatus(streamId, status.ToString().ToUpper(), size), ct);
                    break;

                case QueryCommand.ListStreams:
                    await SendAsync(Message.StreamList(_mgr.List()), ct);
                    break;
            }
        }
        catch (Exception e) { await SendErrorAsync(e.Message, ct); }
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private async Task SendAsync(Message m, CancellationToken ct)
    {
        try
        {
            var bytes = Encoding.UTF8.GetBytes(m.ToJson());
            await _ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, ct);
        }
        catch { /* ignore send failures */ }
    }

    private async Task SendErrorAsync(string message, CancellationToken ct)
    {
        Console.Error.WriteLine($"[{_connId}] error: {message}");
        await SendAsync(Message.Error(message), ct);
    }
}
