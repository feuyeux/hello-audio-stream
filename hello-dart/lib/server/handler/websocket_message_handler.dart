// WebSocket message handler for processing client messages.
// Handles START, STOP, and GET message types.

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../memory/stream_manager.dart';
import '../../src/logger.dart';

/// WebSocket message types
class WebSocketMessage {
  String type;
  String? streamId;
  int? offset;
  int? length;
  String? message;

  WebSocketMessage({
    required this.type,
    this.streamId,
    this.offset,
    this.length,
    this.message,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String? ?? '',
      streamId: json['streamId'] as String?,
      offset: json['offset'] as int?,
      length: json['length'] as int?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (streamId != null) 'streamId': streamId,
      if (offset != null) 'offset': offset,
      if (length != null) 'length': length,
      if (message != null) 'message': message,
    };
  }
}

/// WebSocket message handler for processing client messages.
class WebSocketMessageHandler {
  final StreamManager _streamManager;
  final Function(WebSocketChannel, String)? _onStreamStarted;

  WebSocketMessageHandler({
    StreamManager? streamManager,
    Function(WebSocketChannel, String)? onStreamStarted,
  })  : _streamManager = streamManager ?? StreamManager.getInstance(),
        _onStreamStarted = onStreamStarted;

  /// Handle a text (JSON) control message.
  void handleTextMessage(WebSocketChannel ws, String message) {
    try {
      var json = jsonDecode(message) as Map<String, dynamic>;
      var data = WebSocketMessage.fromJson(json);

      switch (data.type) {
        case 'START':
          _handleStart(ws, data);
          break;
        case 'STOP':
          _handleStop(ws, data);
          break;
        case 'GET':
          _handleGet(ws, data);
          break;
        default:
          Logger.warn('Unknown message type: ${data.type}');
          _sendError(ws, 'Unknown message type: ${data.type}');
      }
    } catch (e) {
      Logger.error('Error parsing JSON message: $e');
      _sendError(ws, 'Invalid JSON format');
    }
  }

  /// Handle binary audio data.
  void handleBinaryMessage(WebSocketChannel ws, List<int> data,
      {String? streamId}) {
    if (streamId == null || streamId.isEmpty) {
      Logger.warn('Received binary data but no active stream for client');
      _sendError(ws, 'No active stream for binary data');
      return;
    }

    Logger.debug(
        'Received ${data.length} bytes of binary data for stream $streamId');
    _streamManager.writeChunk(streamId, data);
  }

  /// Handle START message (create new stream).
  void _handleStart(WebSocketChannel ws, WebSocketMessage data) {
    if (data.streamId == null || data.streamId!.isEmpty) {
      _sendError(ws, 'Missing streamId');
      return;
    }

    if (_streamManager.createStream(data.streamId!)) {
      // Register the stream with the WebSocket connection
      _onStreamStarted?.call(ws, data.streamId!);

      var response = WebSocketMessage(
        type: 'STARTED',
        streamId: data.streamId,
        message: 'Stream started successfully',
      );

      _sendJson(ws, response);
      Logger.info('Stream started: ${data.streamId}');
    } else {
      _sendError(ws, 'Failed to create stream: ${data.streamId}');
    }
  }

  /// Handle STOP message (finalize stream).
  void _handleStop(WebSocketChannel ws, WebSocketMessage data) {
    if (data.streamId == null || data.streamId!.isEmpty) {
      _sendError(ws, 'Missing streamId');
      return;
    }

    if (_streamManager.finalizeStream(data.streamId!)) {
      var response = WebSocketMessage(
        type: 'STOPPED',
        streamId: data.streamId,
        message: 'Stream finalized successfully',
      );

      _sendJson(ws, response);
      Logger.info('Stream finalized: ${data.streamId}');
    } else {
      _sendError(ws, 'Failed to finalize stream: ${data.streamId}');
    }
  }

  /// Handle GET message (read stream data).
  void _handleGet(WebSocketChannel ws, WebSocketMessage data) {
    if (data.streamId == null || data.streamId!.isEmpty) {
      _sendError(ws, 'Missing streamId');
      return;
    }

    var offset = data.offset ?? 0;
    var length = data.length ?? 65536;

    var chunkData = _streamManager.readChunk(data.streamId!, offset, length);

    if (chunkData.isNotEmpty) {
      ws.sink.add(chunkData);
      Logger.debug(
          'Sent ${chunkData.length} bytes for stream ${data.streamId} at offset $offset');
    } else {
      _sendError(ws, 'Failed to read from stream: ${data.streamId}');
    }
  }

  /// Send a JSON message to client.
  void _sendJson(WebSocketChannel ws, WebSocketMessage data) {
    try {
      var json = jsonEncode(data.toJson());
      ws.sink.add(json);
    } catch (e) {
      Logger.error('Error encoding JSON message: $e');
    }
  }

  /// Send an error message to client.
  void _sendError(WebSocketChannel ws, String message) {
    var response = WebSocketMessage(
      type: 'ERROR',
      message: message,
    );
    _sendJson(ws, response);
    Logger.error('Sent error to client: $message');
  }
}
