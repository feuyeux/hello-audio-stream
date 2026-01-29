import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:async/async.dart';
import '../../src/types.dart';
import '../../src/logger.dart';

/// WebSocket client for audio streaming.
/// Uses StreamQueue to properly handle message receiving without consuming the entire stream.
class WebSocketClient {
  final String uri;
  WebSocket? _socket;
  StreamQueue<dynamic>? _messageQueue;

  WebSocketClient(this.uri);

  Future<void> connect() async {
    Logger.info('Connecting to $uri');
    _socket = await WebSocket.connect(uri);
    // Create a StreamQueue to properly consume messages one at a time
    _messageQueue = StreamQueue<dynamic>(_socket!);
    Logger.info('Connected to server');

    // Add a small delay to ensure connection is fully established
    await Future.delayed(Duration(milliseconds: 100));
  }

  Future<void> sendText(ControlMessage message) async {
    final json = jsonEncode(message.toJson());
    Logger.debug('Sending: $json');
    _socket!.add(json);
    // Ensure the message is sent before returning
    await Future.delayed(Duration(milliseconds: 10));
  }

  Future<void> sendBinary(Uint8List data) async {
    Logger.debug('Sending binary data: ${data.length} bytes');
    _socket!.add(data);
    // Small delay to ensure message is sent
    await Future.delayed(Duration(milliseconds: 1));
  }

  Future<String?> receiveText() async {
    if (_messageQueue == null) {
      throw StateError('WebSocket not connected');
    }

    final hasNext = await _messageQueue!.hasNext;
    if (!hasNext) {
      return null;
    }

    final message = await _messageQueue!.next;
    if (message is String) {
      Logger.debug('Received: $message');
      return message;
    }

    // If we received binary when expecting text, log warning and return null
    Logger.warn('Expected text message but received binary');
    return null;
  }

  Future<Uint8List?> receiveBinary() async {
    if (_messageQueue == null) {
      throw StateError('WebSocket not connected');
    }

    final hasNext = await _messageQueue!.hasNext;
    if (!hasNext) {
      return null;
    }

    final message = await _messageQueue!.next;
    if (message is Uint8List) {
      Logger.debug('Received binary data: ${message.length} bytes');
      return message;
    } else if (message is List<int>) {
      final data = Uint8List.fromList(message);
      Logger.debug('Received binary data: ${data.length} bytes');
      return data;
    }

    // If we received text when expecting binary, log warning and return null
    Logger.warn('Expected binary message but received text: $message');
    return null;
  }

  Future<void> close() async {
    await _messageQueue?.cancel();
    await _socket?.close();
    _messageQueue = null;
    _socket = null;
    Logger.info('Disconnected from server');
  }
}
