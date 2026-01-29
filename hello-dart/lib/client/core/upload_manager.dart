import 'dart:math';
import 'package:intl/intl.dart';
import 'websocket_client.dart';
import 'file_manager.dart';
import '../../src/types.dart';
import '../../src/logger.dart';

/// Upload manager
class Upload {
  static const int uploadChunkSize =
      8192; // 8KB to avoid WebSocket frame fragmentation

  static Future<String> upload(WebSocketClient ws, String filePath) async {
    final streamId = _generateStreamId();
    final fileSize = await FileManager.getFileSize(filePath);

    Logger.info('========================================');
    Logger.info('Phase 1: Upload');
    Logger.info('========================================');
    Logger.info('Stream ID: $streamId');
    Logger.info('File size: $fileSize bytes');

    // Send START message
    await ws.sendText(ControlMessage(type: 'START', streamId: streamId));

    // Wait for STARTED response
    final startAck = await ws.receiveText();
    if (startAck == null || !startAck.contains('"type":"STARTED"')) {
      throw Exception('Failed to receive STARTED response');
    }
    Logger.debug('Received STARTED response');

    // Upload file in chunks
    int offset = 0;
    int lastProgress = 0;

    while (offset < fileSize) {
      final chunkSize = min(uploadChunkSize, fileSize - offset);
      final chunk = await FileManager.readChunk(filePath, offset, chunkSize);

      await ws.sendBinary(chunk);
      offset += chunk.length;

      // Report progress
      final progress = ((offset / fileSize) * 100).toInt();
      if (progress >= lastProgress + 25 && progress > lastProgress) {
        Logger.info('Upload progress: $progress% ($offset / $fileSize bytes)');
        lastProgress = (progress ~/ 25) * 25;
      }
    }

    Logger.info('Upload progress: 100% ($fileSize / $fileSize bytes)');

    // Send STOP message
    await ws.sendText(ControlMessage(type: 'STOP', streamId: streamId));

    // Wait for STOPPED response
    final stopAck = await ws.receiveText();
    if (stopAck == null || !stopAck.contains('"type":"STOPPED"')) {
      throw Exception('Failed to receive STOPPED response');
    }
    Logger.debug('Received STOPPED response');

    Logger.info('Upload completed');

    return streamId;
  }

  static String _generateStreamId() {
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final random = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(8, '0');
    return 'stream-$timestamp-$random';
  }
}
