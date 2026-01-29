// Stream context for managing active audio streams.
// Contains stream metadata and cache file handle.
// Matches Python StreamContext and Java StreamContext functionality.

/// Stream status enumeration
enum StreamStatus {
  uploading,
  ready,
  error,
}

/// Stream context containing metadata and state for a single stream.
class StreamContext {
  final String streamId;
  String cachePath;
  dynamic mmapFile;
  int currentOffset;
  int totalSize;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  StreamStatus status;

  /// Create a new StreamContext.
  StreamContext(this.streamId, [this.cachePath = ''])
      : mmapFile = null,
        currentOffset = 0,
        totalSize = 0,
        createdAt = DateTime.now(),
        lastAccessedAt = DateTime.now(),
        status = StreamStatus.uploading;

  /// Update last accessed timestamp
  void updateAccessTime() {
    lastAccessedAt = DateTime.now();
  }
}
