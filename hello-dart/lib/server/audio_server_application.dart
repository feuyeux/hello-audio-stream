// Main entry point for Dart audio stream server.
// Initializes server components and starts the WebSocket server.
// Matches Java AudioServerApplication functionality.

import 'memory/stream_manager.dart';
import 'memory/memory_pool_manager.dart';
import 'network/audio_websocket_server.dart';
import '../src/logger.dart';

/// Audio server application entry point.
class AudioServerApplication {
  /// Run the audio server application.
  static Future<void> run(List<String> arguments) async {
    // Parse command-line arguments
    int port = 8080;
    String path = '/audio';

    for (int i = 0; i < arguments.length; i++) {
      if (arguments[i] == '--port' && i + 1 < arguments.length) {
        port = int.tryParse(arguments[i + 1]) ?? 8080;
        i++;
      } else if (arguments[i] == '--path' && i + 1 < arguments.length) {
        path = arguments[i + 1];
        i++;
      }
    }

    Logger.info('Starting Audio Server on port $port with path $path');

    // Get singleton instances
    var streamManager = StreamManager.getInstance('cache');
    var memoryPool = MemoryPoolManager.getInstance();

    // Create and start WebSocket server
    var server = AudioWebSocketServer(
      port: port,
      path: path,
      streamManager: streamManager,
      memoryPool: memoryPool,
    );

    // Handle graceful shutdown
    Logger.info('Starting server... Press Ctrl+C to stop.');

    // Start server
    await server.start();
  }
}

void main(List<String> arguments) async {
  await AudioServerApplication.run(arguments);
}
