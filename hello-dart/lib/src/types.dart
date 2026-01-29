/// Configuration for the audio client
class Config {
  final String inputPath;
  final String outputPath;
  final String serverUri;
  final bool verbose;

  Config({
    required this.inputPath,
    required this.outputPath,
    required this.serverUri,
    required this.verbose,
  });
}

/// Control message for WebSocket communication
class ControlMessage {
  final String type;
  final String? streamId;
  final int? offset;
  final int? length;
  final String? message;

  ControlMessage({
    required this.type,
    this.streamId,
    this.offset,
    this.length,
    this.message,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type};
    if (streamId != null) json['streamId'] = streamId;
    if (offset != null) json['offset'] = offset;
    if (length != null) json['length'] = length;
    if (message != null) json['message'] = message;
    return json;
  }
}

/// Verification result
class VerificationResult {
  final bool passed;
  final int originalSize;
  final int downloadedSize;
  final String originalChecksum;
  final String downloadedChecksum;

  VerificationResult({
    required this.passed,
    required this.originalSize,
    required this.downloadedSize,
    required this.originalChecksum,
    required this.downloadedChecksum,
  });
}

/// Performance report
class PerformanceReport {
  final int uploadDurationMs;
  final double uploadThroughputMbps;
  final int downloadDurationMs;
  final double downloadThroughputMbps;
  final int totalDurationMs;
  final double averageThroughputMbps;

  PerformanceReport({
    required this.uploadDurationMs,
    required this.uploadThroughputMbps,
    required this.downloadDurationMs,
    required this.downloadThroughputMbps,
    required this.totalDurationMs,
    required this.averageThroughputMbps,
  });
}
