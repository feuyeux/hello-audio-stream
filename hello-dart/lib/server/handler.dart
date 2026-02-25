import 'package:web_socket_channel/web_socket_channel.dart';
import 'protocol.dart';
import 'message.dart';
import 'stream_manager.dart';

class Handler {
  final String connId;
  final StreamManager _manager;
  final WebSocketChannel _ws;
  String? _streamId;

  Handler(this.connId, this._manager, this._ws) {
    _send(Message.connected(connId));
    print('[$connId] connected');
  }

  void onMessage(dynamic msg) {
    try {
      if (msg is String) {
        _handleText(msg);
      } else if (msg is List<int>) {
        _handleBinary(msg);
      }
    } catch (e) {
      _send(Message.error(e.toString()));
    }
  }

  void onClose() {
    if (_streamId != null) {
      _manager.markError(_streamId!);
    }
    print('[$connId] disconnected');
  }

  void _handleText(String json) {
    final (info, msg) = Message.parseCommand(json);

    switch (info.type) {
      case CommandType.stream:
        _handleStream(msg);
      case CommandType.data:
        _handleData(msg);
      case CommandType.query:
        _handleQuery(msg);
    }
  }

  void _handleBinary(List<int> data) {
    if (_streamId == null) {
      _send(Message.error('No active stream'));
      return;
    }
    if (!_manager.write(_streamId!, data)) {
      _send(Message.error('Write failed'));
    }
  }

  void _handleStream(Message msg) {
    switch (msg.command) {
      case 'CREATE':
        _handleCreate(msg);
      case 'COMPLETE':
        _handleComplete();
      case 'CLOSE':
        _handleClose(msg);
      default:
        _send(Message.error('Unknown stream command: ${msg.command}'));
    }
  }

  void _handleData(Message msg) {
    final streamId = msg.streamId ?? '';
    if (streamId.isEmpty) {
      _send(Message.error('Missing streamId'));
      return;
    }
    final offset = msg.offset ?? 0;
    final length = msg.length ?? 65536;
    final data = _manager.read(streamId, offset, length);
    if (data.isNotEmpty) {
      _ws.sink.add(data);
    } else {
      _send(Message.error('Read failed: $streamId'));
    }
  }

  void _handleQuery(Message msg) {
    switch (msg.command) {
      case 'GET_STATUS':
        _handleGetStatus(msg);
      case 'LIST_STREAMS':
        _handleListStreams();
      default:
        _send(Message.error('Unknown query command: ${msg.command}'));
    }
  }

  void _handleCreate(Message msg) {
    final streamId = msg.streamId ?? '';
    if (streamId.isEmpty) {
      _send(Message.error('Missing streamId'));
      return;
    }
    if (_manager.create(streamId)) {
      _streamId = streamId;
      _send(Message.created(streamId));
      print('[$connId] created stream: $streamId');
    } else {
      _send(Message.error('Failed to create stream: $streamId'));
    }
  }

  void _handleComplete() {
    if (_streamId == null) {
      _send(Message.error('No active stream'));
      return;
    }
    if (_manager.complete(_streamId!)) {
      _send(Message.completed(_streamId!));
      print('[$connId] completed stream: $_streamId');
      _streamId = null;
    } else {
      _send(Message.error('Failed to complete stream: $_streamId'));
    }
  }

  void _handleClose(Message msg) {
    final streamId = msg.streamId ?? '';
    if (streamId.isEmpty) {
      _send(Message.error('Missing streamId'));
      return;
    }
    if (_manager.delete(streamId)) {
      _send(Message.closed(streamId));
      print('[$connId] closed stream: $streamId');
    } else {
      _send(Message.error('Failed to close stream: $streamId'));
    }
  }

  void _handleGetStatus(Message msg) {
    final streamId = msg.streamId ?? '';
    if (streamId.isEmpty) {
      _send(Message.error('Missing streamId'));
      return;
    }
    final info = _manager.statusOf(streamId);
    if (info != null) {
      _send(Message.status(streamId, info['status'] as String, info['size'] as int));
    } else {
      _send(Message.error('Stream not found: $streamId'));
    }
  }

  void _handleListStreams() {
    final ids = _manager.list();
    _send(Message.streamList(ids.join(',')));
  }

  void _send(Message msg) {
    _ws.sink.add(msg.toJson());
  }
}
