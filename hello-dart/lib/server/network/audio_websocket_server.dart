// WebSocket server for audio streaming.
// Handles client connections and message routing.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../memory/stream_manager.dart';
import '../memory/memory_pool_manager.dart';
import '../handler/websocket_message_handler.dart';
import '../../src/logger.dart';

/// WebSocket server for handling audio stream uploads and downloads.
class AudioWebSocketServer {
  final int port;
  final String path;
  final StreamManager _streamManager;
  final MemoryPoolManager _memoryPool;
  late WebSocketMessageHandler _messageHandler;
  HttpServer? _server;
  final Map<WebSocketChannel, String> _activeStreams = {};

  /// Create a new WebSocket server.
  AudioWebSocketServer({
    this.port = 8080,
    this.path = '/audio',
    StreamManager? streamManager,
    MemoryPoolManager? memoryPool,
  })  : _streamManager = streamManager ?? StreamManager.getInstance(),
        _memoryPool = memoryPool ?? MemoryPoolManager.getInstance() {
    _messageHandler = WebSocketMessageHandler(
      streamManager: streamManager,
      onStreamStarted: registerStream,
    );
    Logger.info('AudioWebSocketServer initialized on port $port$path');
  }

  /// Start the WebSocket server.
  Future<void> start() async {
    // Create a WebSocket handler that handles all messages
    final wsHandler = webSocketHandler((WebSocketChannel ws) {
      Logger.info('Client connected');

      // Handle messages from this client
      ws.stream.listen(
        (dynamic message) {
          _handleMessage(ws, message);
        },
        onError: (error) {
          Logger.error('Error handling client: $error');
        },
        onDone: () {
          Logger.info('Client disconnected');
          _cleanupClient(ws);
        },
      );
    });

    // Create a handler that routes requests based on path
    Handler handler = (Request request) {
      if (request.url.path == path.replaceFirst('/', '')) {
        return wsHandler(request);
      }
      return Response.notFound('Not found');
    };

    try {
      _server = await serve(
        handler,
        InternetAddress.anyIPv4,
        port,
      );
      Logger.info('WebSocket server started on ws://0.0.0.0:$port$path');
    } catch (e) {
      Logger.error('Failed to start WebSocket server: $e');
      rethrow;
    }
  }

  /// Stop the WebSocket server.
  Future<void> stop() async {
    // Close all client connections
    for (final ws in _activeStreams.keys.toList()) {
      _cleanupClient(ws);
    }

    // Stop the server
    await _server?.close();
    Logger.info('WebSocket server stopped');
  }

  /// Handle incoming message from a client.
  void _handleMessage(WebSocketChannel ws, dynamic message) {
    if (message is String) {
      // Text (JSON control message)
      _messageHandler.handleTextMessage(ws, message);
    } else if (message is List<int>) {
      // Binary audio data
      final streamId = _activeStreams[ws];
      _messageHandler.handleBinaryMessage(ws, message, streamId: streamId);
    } else if (message is Uint8List) {
      // Binary audio data (Uint8List)
      final dataList = message.toList();
      final streamId = _activeStreams[ws];
      _messageHandler.handleBinaryMessage(ws, dataList, streamId: streamId);
    } else {
      Logger.warn('Unknown message type: ${message.runtimeType}');
    }
  }

  /// Clean up a client connection.
  void _cleanupClient(WebSocketChannel ws) {
    _activeStreams.remove(ws);
  }

  /// Register a stream ID for a WebSocket connection.
  void registerStream(WebSocketChannel ws, String streamId) {
    _activeStreams[ws] = streamId;
  }

  /// Unregister a stream ID for a WebSocket connection.
  void unregisterStream(WebSocketChannel ws) {
    _activeStreams.remove(ws);
  }

  /// Get the active stream ID for a WebSocket connection.
  String? getActiveStream(WebSocketChannel ws) {
    return _activeStreams[ws];
  }
}
