// Main entry point for Dart audio stream client.
// Handles command-line parsing and coordinates upload/download operations.
// Matches Java AudioClientApplication functionality.

import 'dart:io';
import '../src/cli_parser.dart';
import '../src/logger.dart';
import '../src/types.dart';
import 'core/websocket_client.dart';
import 'core/upload_manager.dart';
import 'core/download_manager.dart';
import 'core/file_manager.dart';
import 'util/verification_module.dart';
import 'util/performance_monitor.dart';

/// Audio client application entry point.
class AudioClientApplication {
  /// Run the audio client application.
  static Future<void> run(List<String> arguments) async {
    try {
      final config = CliParser.parse(arguments);
      if (config == null) {
        exit(1);
      }

      await runWorkflow(config);
      exit(0);
    } catch (e) {
      Logger.error('Fatal error: $e');
      exit(1);
    }
  }

  /// Execute the upload/download workflow.
  static Future<void> runWorkflow(Config config) async {
    Logger.info('Audio Stream Client');
    Logger.info('Input: ${config.inputPath}');
    Logger.info('Output: ${config.outputPath}');
    Logger.info('Server: ${config.serverUri}');

    // Initialize performance monitor
    final performance = Performance();
    final fileSize = await FileManager.getFileSize(config.inputPath);
    performance.setFileSize(fileSize);

    // Connect to WebSocket server
    final ws = WebSocketClient(config.serverUri);
    await ws.connect();

    try {
      // Upload file
      performance.startUpload();
      final streamId = await Upload.upload(ws, config.inputPath);
      performance.endUpload();

      // Sleep 2 seconds after upload
      Logger.info('Upload successful, sleeping for 2 seconds...');
      await Future.delayed(Duration(seconds: 2));

      // Download file
      performance.startDownload();
      await Download.download(ws, streamId, config.outputPath, fileSize);
      performance.endDownload();

      // Sleep 2 seconds after download
      Logger.info('Download successful, sleeping for 2 seconds...');
      await Future.delayed(Duration(seconds: 2));

      // Verify integrity
      final verification =
          await Verification.verify(config.inputPath, config.outputPath);

      // Report performance
      final report = performance.getReport();
      performance.printReport(report);

      // Exit with appropriate code
      if (verification.passed) {
        Logger.info('SUCCESS: Stream completed successfully');
      } else {
        Logger.error('FAILURE: File verification failed');
        throw Exception('Verification failed');
      }
    } finally {
      await ws.close();
    }
  }
}

void main(List<String> arguments) async {
  await AudioClientApplication.run(arguments);
}
