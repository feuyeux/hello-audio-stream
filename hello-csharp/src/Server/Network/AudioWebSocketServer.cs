using System;
using System.Collections.Concurrent;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using AudioStreamServer.Handler;
using AudioStreamServer.Memory;

namespace AudioStreamServer.Network;

/// <summary>
/// WebSocket server for handling audio stream uploads and downloads.
/// </summary>
public class AudioWebSocketServer
{
    private readonly int _port;
    private readonly string _path;
    private readonly StreamManager _streamManager;
    private readonly MemoryPoolManager _memoryPool;
    private readonly ConcurrentDictionary<WebSocket, string> _activeStreams;
    private readonly ConcurrentDictionary<WebSocket, CancellationTokenSource> _clientCancellationTokens;
    private HttpListener? _httpListener;
    private CancellationTokenSource? _serverCts;
    private Task? _serverTask;

    /// <summary>
    /// Create a new WebSocket server.
    /// </summary>
    public AudioWebSocketServer(
        int port = 8080,
        string path = "/audio",
        StreamManager? streamManager = null,
        MemoryPoolManager? memoryPool = null)
    {
        _port = port;
        _path = path;
        _streamManager = streamManager ?? StreamManager.GetInstance();
        _memoryPool = memoryPool ?? MemoryPoolManager.GetInstance();
        _activeStreams = new ConcurrentDictionary<WebSocket, string>();
        _clientCancellationTokens = new ConcurrentDictionary<WebSocket, CancellationTokenSource>();

        Logger.Instance.Info($"AudioWebSocketServer initialized on port {port}{path}");
    }

    /// <summary>
    /// Start the WebSocket server.
    /// </summary>
    public async Task Start()
    {
        _httpListener = new HttpListener();
        // Use localhost to avoid requiring admin privileges
        _httpListener.Prefixes.Add($"http://localhost:{_port}/");
        _serverCts = new CancellationTokenSource();

        try
        {
            _httpListener.Start();
            Logger.Instance.Info($"WebSocket server started on ws://localhost:{_port}{_path}");

            _serverTask = AcceptClientsAsync(_serverCts.Token);
            await _serverTask;
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Failed to start WebSocket server: {ex.Message}");
            throw;
        }
    }

    /// <summary>
    /// Stop the WebSocket server.
    /// </summary>
    public void Stop()
    {
        _serverCts?.Cancel();
        _httpListener?.Stop();
        _httpListener?.Close();

        Logger.Instance.Info("WebSocket server stopped");
    }

    /// <summary>
    /// Accept incoming client connections.
    /// </summary>
    private async Task AcceptClientsAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var context = await _httpListener!.GetContextAsync();

                // Check if request URL matches our WebSocket path
                var requestPath = context.Request.Url?.LocalPath ?? "";
                if (requestPath == _path || requestPath == _path + "/")
                {
                    if (context.Request.IsWebSocketRequest)
                    {
                        _ = HandleClientAsync(context, cancellationToken);
                    }
                    else
                    {
                        context.Response.StatusCode = 400;
                        context.Response.Close();
                    }
                }
                else
                {
                    // Request for a different path - return 404
                    context.Response.StatusCode = 404;
                    context.Response.Close();
                }
            }
            catch (HttpListenerException) when (cancellationToken.IsCancellationRequested)
            {
                // Expected during shutdown
                break;
            }
            catch (Exception ex)
            {
                Logger.Instance.Error($"Error accepting client: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Handle a WebSocket client connection.
    /// </summary>
    private async Task HandleClientAsync(HttpListenerContext context, CancellationToken cancellationToken)
    {
        var wsContext = await context.AcceptWebSocketAsync(null);
        var webSocket = wsContext.WebSocket;
        var remoteEndPoint = context.Request.RemoteEndPoint?.ToString() ?? "unknown";
        var clientCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

        _clientCancellationTokens.TryAdd(webSocket, clientCts);

        Logger.Instance.Info($"Client connected: {remoteEndPoint}");

        try
        {
            var buffer = new byte[1024 * 64]; // 64KB buffer

            while (webSocket.State == WebSocketState.Open && !cancellationToken.IsCancellationRequested)
            {
                var result = await webSocket.ReceiveAsync(
                    new ArraySegment<byte>(buffer),
                    clientCts.Token);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    await webSocket.CloseAsync(
                        WebSocketCloseStatus.NormalClosure,
                        "Closing",
                        CancellationToken.None);
                    break;
                }

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    await HandleTextMessageAsync(webSocket, message);
                }
                else if (result.MessageType == WebSocketMessageType.Binary)
                {
                    var data = new byte[result.Count];
                    Array.Copy(buffer, 0, data, 0, result.Count);
                    await HandleBinaryMessageAsync(webSocket, data);
                }
            }
        }
        catch (WebSocketException ex)
        {
            Logger.Instance.Warning($"Client disconnected: {remoteEndPoint} - {ex.Message}");
        }
        catch (OperationCanceledException)
        {
            // Expected during shutdown
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error handling client {remoteEndPoint}: {ex.Message}");
        }
        finally
        {
            _activeStreams.TryRemove(webSocket, out _);
            _clientCancellationTokens.TryRemove(webSocket, out var cts);
            cts?.Cancel();
            cts?.Dispose();

            try
            {
                if (webSocket.State == WebSocketState.Open)
                {
                    await webSocket.CloseAsync(
                        WebSocketCloseStatus.NormalClosure,
                        "Closing",
                        CancellationToken.None);
                }
                webSocket.Dispose();
            }
            catch { }

            Logger.Instance.Info($"Client disconnected: {remoteEndPoint}");
        }
    }

    /// <summary>
    /// Handle a text (JSON) control message.
    /// </summary>
    private Task HandleTextMessageAsync(WebSocket ws, string message)
    {
        try
        {
            var data = JsonSerializer.Deserialize<WebSocketMessage>(message);
            if (data == null)
            {
                Logger.Instance.Error("Invalid JSON message");
                SendErrorAsync(ws, "Invalid JSON format").ConfigureAwait(false);
                return Task.CompletedTask;
            }

            return data.Type switch
            {
                "START" => HandleStartAsync(ws, data),
                "STOP" => HandleStopAsync(ws, data),
                "GET" => HandleGetAsync(ws, data),
                _ => Task.Run(() =>
                {
                    Logger.Instance.Warning($"Unknown message type: {data.Type}");
                    SendErrorAsync(ws, $"Unknown message type: {data.Type}").ConfigureAwait(false);
                })
            };
        }
        catch (JsonException ex)
        {
            Logger.Instance.Error($"Error parsing JSON message: {ex.Message}");
            SendErrorAsync(ws, "Invalid JSON format").ConfigureAwait(false);
            return Task.CompletedTask;
        }
    }

    /// <summary>
    /// Handle binary audio data.
    /// </summary>
    private Task HandleBinaryMessageAsync(WebSocket ws, byte[] data)
    {
        if (_activeStreams.TryGetValue(ws, out string? streamId) && !string.IsNullOrEmpty(streamId))
        {
            Logger.Instance.Debug($"Received {data.Length} bytes of binary data for stream {streamId}");
            _streamManager.WriteChunk(streamId, data);
            return Task.CompletedTask;
        }
        else
        {
            Logger.Instance.Warning("Received binary data but no active stream for client");
            SendErrorAsync(ws, "No active stream for binary data").ConfigureAwait(false);
            return Task.CompletedTask;
        }
    }

    /// <summary>
    /// Handle START message (create new stream).
    /// </summary>
    private async Task HandleStartAsync(WebSocket ws, WebSocketMessage data)
    {
        if (string.IsNullOrEmpty(data.StreamId))
        {
            await SendErrorAsync(ws, "Missing streamId");
            return;
        }

        if (_streamManager.CreateStream(data.StreamId!))
        {
            _activeStreams[ws] = data.StreamId!;

            var response = new WebSocketMessage
            {
                Type = "STARTED",
                StreamId = data.StreamId,
                Message = "Stream started successfully"
            };

            await SendJsonAsync(ws, response);
            Logger.Instance.Info($"Stream started: {data.StreamId}");
        }
        else
        {
            await SendErrorAsync(ws, $"Failed to create stream: {data.StreamId}");
        }
    }

    /// <summary>
    /// Handle STOP message (finalize stream).
    /// </summary>
    private async Task HandleStopAsync(WebSocket ws, WebSocketMessage data)
    {
        if (string.IsNullOrEmpty(data.StreamId))
        {
            await SendErrorAsync(ws, "Missing streamId");
            return;
        }

        if (_streamManager.FinalizeStream(data.StreamId!))
        {
            var response = new WebSocketMessage
            {
                Type = "STOPPED",
                StreamId = data.StreamId,
                Message = "Stream finalized successfully"
            };

            await SendJsonAsync(ws, response);
            Logger.Instance.Info($"Stream finalized: {data.StreamId}");
        }
        else
        {
            await SendErrorAsync(ws, $"Failed to finalize stream: {data.StreamId}");
        }
    }

    /// <summary>
    /// Handle GET message (read stream data).
    /// </summary>
    private async Task HandleGetAsync(WebSocket ws, WebSocketMessage data)
    {
        if (string.IsNullOrEmpty(data.StreamId))
        {
            await SendErrorAsync(ws, "Missing streamId");
            return;
        }

        long offset = data.Offset ?? 0;
        int length = data.Length ?? 65536;

        byte[] chunkData = _streamManager.ReadChunk(data.StreamId!, offset, length);

        if (chunkData.Length > 0)
        {
            await SendBinaryAsync(ws, chunkData);
            Logger.Instance.Debug($"Sent {chunkData.Length} bytes for stream {data.StreamId} at offset {offset}");
        }
        else
        {
            await SendErrorAsync(ws, $"Failed to read from stream: {data.StreamId}");
        }
    }

    /// <summary>
    /// Send a JSON message to client.
    /// </summary>
    private async Task SendJsonAsync(WebSocket ws, WebSocketMessage data)
    {
        try
        {
            string json = JsonSerializer.Serialize(data);
            await SendTextAsync(ws, json);
        }
        catch (Exception ex)
        {
            Logger.Instance.Error($"Error encoding JSON message: {ex.Message}");
        }
    }

    /// <summary>
    /// Send an error message to client.
    /// </summary>
    private async Task SendErrorAsync(WebSocket ws, string message)
    {
        var response = new WebSocketMessage
        {
            Type = "ERROR",
            Message = message
        };
        await SendJsonAsync(ws, response);
        Logger.Instance.Error($"Sent error to client: {message}");
    }

    /// <summary>
    /// Send binary data to client.
    /// </summary>
    private async Task SendBinaryAsync(WebSocket ws, byte[] data)
    {
        if (_clientCancellationTokens.TryGetValue(ws, out var cts) && ws.State == WebSocketState.Open)
        {
            await ws.SendAsync(
                new ArraySegment<byte>(data),
                WebSocketMessageType.Binary,
                true,
                cts.Token);
        }
    }

    /// <summary>
    /// Send text data to client.
    /// </summary>
    private async Task SendTextAsync(WebSocket ws, string text)
    {
        byte[] bytes = Encoding.UTF8.GetBytes(text);
        if (_clientCancellationTokens.TryGetValue(ws, out var cts) && ws.State == WebSocketState.Open)
        {
            await ws.SendAsync(
                new ArraySegment<byte>(bytes),
                WebSocketMessageType.Text,
                true,
                cts.Token);
        }
    }
}
