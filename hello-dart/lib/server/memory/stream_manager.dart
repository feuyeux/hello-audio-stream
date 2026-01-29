// Stream manager for managing active audio streams.
// Thread-safe registry of stream contexts.
// Matches Python StreamManager and Java StreamManager functionality.

import 'dart:io';
import '../../src/logger.dart';

import 'stream_context.dart';
import 'memory_mapped_cache.dart';

/// Stream manager for managing multiple concurrent streams.
class StreamManager {
  static StreamManager? _instance;
  final String cacheDirectory;
  final Map<String, StreamContext> _streams = {};

  /// Get the singleton instance of StreamManager.
  static StreamManager getInstance([String cacheDirectory = 'cache']) {
    _instance ??= StreamManager._internal(cacheDirectory);
    return _instance!;
  }

  /// Private constructor for singleton pattern.
  StreamManager._internal(this.cacheDirectory) {
    // Create cache directory if it doesn't exist
    Directory(cacheDirectory).createSync(recursive: true);

    Logger.info(
        'StreamManager initialized with cache directory: $cacheDirectory');
  }

  /// Create a new stream.
  bool createStream(String streamId) {
    // Check if stream already exists
    if (_streams.containsKey(streamId)) {
      Logger.warn('Stream already exists: $streamId');
      return false;
    }

    try {
      // Create new stream context
      String cachePath = _getCachePath(streamId);
      var context = StreamContext(streamId, cachePath);
      context.status = StreamStatus.uploading;
      context.updateAccessTime();

      // Create memory-mapped cache file
      var mmapFile = MemoryMappedCache(cachePath);
      // Note: This is synchronous, in production you'd use async
      context.mmapFile = mmapFile;

      // Add to registry
      _streams[streamId] = context;

      Logger.info('Created stream: $streamId at path: $cachePath');
      return true;
    } catch (e) {
      Logger.error('Failed to create stream $streamId: $e');
      return false;
    }
  }

  /// Get a stream context.
  StreamContext? getStream(String streamId) {
    var context = _streams[streamId];
    if (context != null) {
      context.updateAccessTime();
    }
    return context;
  }

  /// Delete a stream.
  bool deleteStream(String streamId) {
    var context = _streams[streamId];
    if (context == null) {
      Logger.warn('Stream not found for deletion: $streamId');
      return false;
    }

    try {
      // Remove cache file
      if (File(context.cachePath).existsSync()) {
        File(context.cachePath).deleteSync();
      }

      // Remove from registry
      _streams.remove(streamId);

      Logger.info('Deleted stream: $streamId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete stream $streamId: $e');
      return false;
    }
  }

  /// List all active streams.
  List<String> listActiveStreams() {
    return _streams.keys.toList();
  }

  /// Write a chunk of data to a stream.
  bool writeChunk(String streamId, List<int> data) {
    var stream = getStream(streamId);
    if (stream == null) {
      Logger.error('Stream not found for write: $streamId');
      return false;
    }

    if (stream.status != StreamStatus.uploading) {
      Logger.error('Stream $streamId is not in uploading state');
      return false;
    }

    try {
      // Write data to memory-mapped file
      var mmapFile = stream.mmapFile;
      if (mmapFile == null) {
        return false;
      }

      // Write data at current offset using synchronous method
      mmapFile.writeSync(stream.currentOffset, data);

      stream.currentOffset += data.length;
      stream.totalSize += data.length;
      stream.updateAccessTime();

      Logger.debug(
          'Wrote ${data.length} bytes to stream $streamId at offset ${stream.currentOffset - data.length}');
      return true;
    } catch (e) {
      Logger.error('Error writing to stream $streamId: $e');
      return false;
    }
  }

  /// Read a chunk of data from a stream.
  List<int> readChunk(String streamId, int offset, int length) {
    var stream = getStream(streamId);
    if (stream == null) {
      Logger.error('Stream not found for read: $streamId');
      return [];
    }

    try {
      // Read data from memory-mapped file
      var mmapFile = stream.mmapFile;
      if (mmapFile == null) {
        return [];
      }

      stream.updateAccessTime();

      // Read data from the file using synchronous method
      var data = mmapFile.readSync(offset, length);
      Logger.debug(
          'Read ${data.length} bytes from stream $streamId at offset $offset');
      return data;
    } catch (e) {
      Logger.error('Error reading from stream $streamId: $e');
      return [];
    }
  }

  /// Finalize a stream.
  bool finalizeStream(String streamId) {
    var stream = getStream(streamId);
    if (stream == null) {
      Logger.error('Stream not found for finalization: $streamId');
      return false;
    }

    if (stream.status != StreamStatus.uploading) {
      Logger.warn(
          'Stream $streamId is not in uploading state for finalization');
      return false;
    }

    try {
      // Finalize memory-mapped file
      var mmapFile = stream.mmapFile;
      if (mmapFile == null) {
        return false;
      }

      stream.status = StreamStatus.ready;
      stream.updateAccessTime();

      Logger.info(
          'Finalized stream: $streamId with ${stream.totalSize} bytes');
      return true;
    } catch (e) {
      Logger.error('Error finalizing stream $streamId: $e');
      return false;
    }
  }

  /// Clean up old streams (older than maxAgeHours).
  void cleanupOldStreams([int maxAgeHours = 24]) {
    var now = DateTime.now();
    var cutoff = Duration(hours: maxAgeHours);

    var toRemove = <String>[];
    _streams.forEach((streamId, context) {
      var age = now.difference(context.lastAccessedAt);
      if (age > cutoff) {
        toRemove.add(streamId);
      }
    });

    for (var streamId in toRemove) {
      Logger.info('Cleaning up old stream: $streamId');
      deleteStream(streamId);
    }
  }

  /// Get cache file path for a stream.
  String _getCachePath(String streamId) {
    return '$cacheDirectory/$streamId.cache';
  }
}
