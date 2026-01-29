// Chunk manager for handling file chunking operations.
// Provides utilities for splitting and reassembling file chunks.
// Matches Java ChunkManager functionality.

import 'dart:typed_data';

/// Chunk manager for file chunking operations.
class ChunkManager {
  static const int defaultChunkSize = 8192; // 8KB

  /// Split data into chunks of specified size.
  static List<Uint8List> splitIntoChunks(Uint8List data, int chunkSize) {
    final chunks = <Uint8List>[];
    int offset = 0;

    while (offset < data.length) {
      final end =
          (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
      chunks.add(data.sublist(offset, end));
      offset = end;
    }

    return chunks;
  }

  /// Reassemble chunks into a single data buffer.
  static Uint8List reassembleChunks(List<Uint8List> chunks) {
    final totalSize = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalSize);

    int offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Calculate the number of chunks needed for a given file size.
  static int calculateChunkCount(int fileSize, int chunkSize) {
    return (fileSize + chunkSize - 1) ~/ chunkSize;
  }
}
