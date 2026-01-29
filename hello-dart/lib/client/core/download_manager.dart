import 'dart:math';
import 'websocket_client.dart';
import 'file_manager.dart';
import '../../src/types.dart';
import '../../src/logger.dart';

/// Download manager
class Download {
  static const int downloadChunkSize = 8192; // 8KB per GET request

  static Future<void> download(WebSocketClient ws, String streamId,
      String outputPath, int fileSize) async {
    Logger.info('========================================');
    Logger.info('Phase 2: Download');
    Logger.info('========================================');
    Logger.info('Output path: $outputPath');
    Logger.info('Expected size: $fileSize bytes');

    // Delete output file if it exists
    await FileManager.deleteFile(outputPath);

    int offset = 0;
    int lastProgress = 0;

    while (offset < fileSize) {
      final length = min(downloadChunkSize, fileSize - offset);

      // Send GET message
      await ws.sendText(ControlMessage(
        type: 'GET',
        streamId: streamId,
        offset: offset,
        length: length,
      ));

      // Receive binary data
      final data = await ws.receiveBinary();
      if (data == null) {
        throw Exception('Failed to receive data at offset $offset');
      }

      // Write to file
      await FileManager.writeChunk(outputPath, data, append: true);
      offset += data.length;

      // Report progress
      final progress = ((offset / fileSize) * 100).toInt();
      if (progress >= lastProgress + 25 && progress > lastProgress) {
        Logger.info(
            'Download progress: $progress% ($offset / $fileSize bytes)');
        lastProgress = (progress ~/ 25) * 25;
      }
    }

    Logger.info('Download progress: 100% ($fileSize / $fileSize bytes)');
    Logger.info('Download completed');
  }
}
