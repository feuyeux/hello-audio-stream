import '../../src/types.dart';
import '../../src/logger.dart';

/// Performance monitoring
class Performance {
  int _uploadStartMs = 0;
  int _uploadEndMs = 0;
  int _downloadStartMs = 0;
  int _downloadEndMs = 0;
  int _fileSize = 0;

  void setFileSize(int size) {
    _fileSize = size;
  }

  void startUpload() {
    _uploadStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  void endUpload() {
    _uploadEndMs = DateTime.now().millisecondsSinceEpoch;
  }

  void startDownload() {
    _downloadStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  void endDownload() {
    _downloadEndMs = DateTime.now().millisecondsSinceEpoch;
  }

  PerformanceReport getReport() {
    final uploadDurationMs = _uploadEndMs - _uploadStartMs;
    final downloadDurationMs = _downloadEndMs - _downloadStartMs;
    final totalDurationMs = _downloadEndMs - _uploadStartMs;

    final uploadThroughputMbps =
        _calculateThroughput(_fileSize, uploadDurationMs);
    final downloadThroughputMbps =
        _calculateThroughput(_fileSize, downloadDurationMs);
    final averageThroughputMbps =
        _calculateThroughput(_fileSize * 2, totalDurationMs);

    return PerformanceReport(
      uploadDurationMs: uploadDurationMs,
      uploadThroughputMbps: uploadThroughputMbps,
      downloadDurationMs: downloadDurationMs,
      downloadThroughputMbps: downloadThroughputMbps,
      totalDurationMs: totalDurationMs,
      averageThroughputMbps: averageThroughputMbps,
    );
  }

  void printReport(PerformanceReport report) {
    Logger.info('========================================');
    Logger.info('Phase 4: Performance Report');
    Logger.info('========================================');
    Logger.info('Upload:');
    Logger.info('  Duration: ${report.uploadDurationMs} ms');
    Logger.info(
        '  Throughput: ${report.uploadThroughputMbps.toStringAsFixed(2)} Mbps');
    Logger.info('Download:');
    Logger.info('  Duration: ${report.downloadDurationMs} ms');
    Logger.info(
        '  Throughput: ${report.downloadThroughputMbps.toStringAsFixed(2)} Mbps');
    Logger.info('Total:');
    Logger.info('  Duration: ${report.totalDurationMs} ms');
    Logger.info(
        '  Average throughput: ${report.averageThroughputMbps.toStringAsFixed(2)} Mbps');
    Logger.info('========================================');
  }

  double _calculateThroughput(int bytes, int durationMs) {
    if (durationMs == 0) return 0.0;
    final bits = bytes * 8.0;
    final seconds = durationMs / 1000.0;
    return bits / seconds / 1000000.0;
  }
}
