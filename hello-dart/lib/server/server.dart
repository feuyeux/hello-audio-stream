import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'handler.dart';
import 'stream_manager.dart';

class Server {
  final int port;
  final StreamManager _manager;
  int _connSeq = 0;

  Server({this.port = 8080, String cacheDir = 'cache'})
      : _manager = StreamManager(cacheDir: cacheDir);

  Future<void> start() async {
    Timer.periodic(const Duration(seconds: 30), (_) {
      final removed = _manager.cleanup();
      if (removed > 0) {
        final stats = _manager.stats();
        print('Cleanup: removed $removed streams, total=${stats['total']}');
      }
    });

    final handler = webSocketHandler((ws, protocol) {
      final connId = 'c-${++_connSeq}';
      final h = Handler(connId, _manager, ws);

      ws.stream.listen(
        (msg) => h.onMessage(msg),
        onError: (e) => print('Error: $e'),
        onDone: () => h.onClose(),
      );
    });

    await serve(handler, InternetAddress.anyIPv4, port);
    print('Server started on ws://0.0.0.0:$port');
  }
}

void main(List<String> arguments) async {
  var port = 8080;
  var cacheDir = 'cache';

  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--port' && i + 1 < arguments.length) {
      port = int.tryParse(arguments[i + 1]) ?? 8080;
      i++;
    } else if (arguments[i] == '--cache-dir' && i + 1 < arguments.length) {
      cacheDir = arguments[i + 1];
      i++;
    }
  }

  final server = Server(port: port, cacheDir: cacheDir);
  await server.start();
}
