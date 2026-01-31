using System;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace AudioStreamCache.Client.Core;

/// <summary>
/// WebSocket client for communication with the server
/// </summary>
public class WebSocketClient : IDisposable
{
    private readonly string _uri;
    private ClientWebSocket? _ws;
    private readonly CancellationTokenSource _cts;

    public WebSocketClient(string uri)
    {
        _uri = uri;
        _cts = new CancellationTokenSource();
    }

    public async Task ConnectAsync()
    {
        _ws = new ClientWebSocket();
        await _ws.ConnectAsync(new Uri(_uri), _cts.Token);
        Logger.Debug($"Connected to WebSocket server: {_uri}");
    }

    public async Task SendTextAsync(string message)
    {
        if (_ws == null || _ws.State != WebSocketState.Open)
        {
            throw new InvalidOperationException("WebSocket is not connected");
        }

        byte[] buffer = Encoding.UTF8.GetBytes(message);
        await _ws.SendAsync(new ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, _cts.Token);
        Logger.Debug($"Sent text message: {message}");
    }

    public async Task SendBinaryAsync(byte[] data)
    {
        if (_ws == null || _ws.State != WebSocketState.Open)
        {
            throw new InvalidOperationException("WebSocket is not connected");
        }

        await _ws.SendAsync(new ArraySegment<byte>(data), WebSocketMessageType.Binary, true, _cts.Token);
        Logger.Debug($"Sent binary data: {data.Length} bytes");
    }

    public async Task<(WebSocketMessageType type, byte[] data)> ReceiveAsync()
    {
        if (_ws == null || _ws.State != WebSocketState.Open)
        {
            throw new InvalidOperationException("WebSocket is not connected");
        }

        byte[] buffer = new byte[65536];
        var result = await _ws.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);
        
        byte[] data = new byte[result.Count];
        Array.Copy(buffer, data, result.Count);
        
        Logger.Debug($"Received {result.MessageType} message: {data.Length} bytes");
        return (result.MessageType, data);
    }

    public async Task<ControlMessage?> ReceiveTextAsync()
    {
        var (type, data) = await ReceiveAsync();
        
        if (type != WebSocketMessageType.Text)
        {
            Logger.Warn($"Expected text message but received {type}");
            return null;
        }

        string json = Encoding.UTF8.GetString(data);
        Logger.Debug($"Received text message: {json}");
        
        return JsonSerializer.Deserialize<ControlMessage>(json);
    }

    public async Task<byte[]> ReceiveBinaryAsync()
    {
        var (type, data) = await ReceiveAsync();
        
        if (type != WebSocketMessageType.Binary)
        {
            throw new InvalidOperationException($"Expected binary message but received {type}");
        }

        return data;
    }

    public async Task CloseAsync()
    {
        if (_ws != null && _ws.State == WebSocketState.Open)
        {
            await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "Client closing", _cts.Token);
            Logger.Debug("WebSocket connection closed");
        }
    }

    public void Dispose()
    {
        _ws?.Dispose();
        _cts.Dispose();
    }
}
