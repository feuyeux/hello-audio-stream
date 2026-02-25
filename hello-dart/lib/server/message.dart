import 'dart:convert';
import 'protocol.dart';

class Message {
  final String command;
  final String? streamId;
  final int? offset;
  final int? length;
  final String? message;
  final String? status;
  final int? size;
  final String? streams;

  const Message({
    required this.command,
    this.streamId,
    this.offset,
    this.length,
    this.message,
    this.status,
    this.size,
    this.streams,
  });

  String toJson() {
    final map = <String, dynamic>{'command': command};
    if (streamId != null) map['streamId'] = streamId;
    if (offset != null) map['offset'] = offset;
    if (length != null) map['length'] = length;
    if (message != null) map['message'] = message;
    if (status != null) map['status'] = status;
    if (size != null) map['size'] = size;
    if (streams != null) map['streams'] = streams;
    return jsonEncode(map);
  }

  static Message parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (!data.containsKey('command')) {
      throw ArgumentError('Invalid message: missing command field');
    }
    return Message(
      command: data['command'] as String,
      streamId: data['streamId'] as String?,
      offset: data['offset'] as int?,
      length: data['length'] as int?,
      message: data['message'] as String?,
      status: data['status'] as String?,
      size: data['size'] as int?,
      streams: data['streams'] as String?,
    );
  }

  static (CommandInfo, Message) parseCommand(String json) {
    final msg = parse(json);
    final info = Protocol.lookup(msg.command);
    if (info == null) {
      throw ArgumentError('Unknown command: ${msg.command}');
    }
    return (info, msg);
  }

  // --- Factory methods ---

  factory Message.connected(String connId) =>
      Message(command: 'CONNECTED', streamId: connId);

  factory Message.created(String streamId) =>
      Message(command: 'CREATED', streamId: streamId);

  factory Message.completed(String streamId) =>
      Message(command: 'COMPLETED', streamId: streamId);

  factory Message.closed(String streamId) =>
      Message(command: 'CLOSED', streamId: streamId);

  factory Message.status(String streamId, String status, int size) =>
      Message(command: 'STATUS', streamId: streamId, status: status, size: size);

  factory Message.streamList(String streams) =>
      Message(command: 'STREAM_LIST', streams: streams);

  factory Message.error(String message) =>
      Message(command: 'ERROR', message: message);
}
