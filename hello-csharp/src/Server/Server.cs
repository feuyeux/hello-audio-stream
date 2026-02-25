using System.Net;
using System.Net.WebSockets;

namespace AudioStreamServer;

/// <summary>WebSocket audio stream server using HttpListener.</summary>
public sealed class Server
{
    private readonly int _port;
    private readonly StreamManager _mgr;
    private readonly CancellationTokenSource _cts = new();
    private HttpListener? _listener;
    private int _connSeq;

    public Server(int port, string cacheDir = "audio/output")
    {
        _port = port;
        _mgr = new StreamManager(cacheDir);
    }

    public async Task RunAsync()
    {
        _listener = new HttpListener();
        _listener.Prefixes.Add($"http://localhost:{_port}/");
        _listener.Start();
        Console.WriteLine($"Server listening on ws://localhost:{_port}");

        // Start cleanup timer
        _ = CleanupLoopAsync(_cts.Token);

        try
        {
            while (!_cts.IsCancellationRequested)
            {
                var ctx = await _listener.GetContextAsync();
                if (ctx.Request.IsWebSocketRequest)
                    _ = Task.Run(() => HandleConnectionAsync(ctx));
                else
                {
                    ctx.Response.StatusCode = 400;
                    ctx.Response.Close();
                }
            }
        }
        catch (HttpListenerException) when (_cts.IsCancellationRequested) { /* shutdown */ }
        catch (ObjectDisposedException) { /* shutdown */ }
    }

    public void Stop()
    {
        _cts.Cancel();
        _listener?.Stop();
        _listener?.Close();
    }

    // ── Internal ────────────────────────────────────────────────────────

    private async Task HandleConnectionAsync(HttpListenerContext ctx)
    {
        WebSocket? ws = null;
        try
        {
            var wsCtx = await ctx.AcceptWebSocketAsync(null);
            ws = wsCtx.WebSocket;
            var connId = $"c-{Interlocked.Increment(ref _connSeq)}";
            Console.WriteLine($"[{connId}] connected from {ctx.Request.RemoteEndPoint}");

            var handler = new Handler(_mgr, connId, ws);
            await handler.RunAsync(_cts.Token);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Connection error: {ex.Message}");
        }
        finally
        {
            ws?.Dispose();
        }
    }

    private async Task CleanupLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(30), ct);
            try
            {
                var removed = _mgr.Cleanup();
                if (removed > 0) Console.WriteLine($"Cleanup removed {removed} stream(s)");
                var (total, uploading, ready, error) = _mgr.Stats();
                Console.WriteLine($"Stats: total={total} uploading={uploading} ready={ready} error={error}");
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex) { Console.Error.WriteLine($"Cleanup error: {ex.Message}"); }
        }
    }
}
