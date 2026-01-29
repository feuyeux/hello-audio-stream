// Memory pool manager for efficient buffer reuse.
// Pre-allocates buffers to minimize allocation overhead.
// Implemented as a singleton to ensure a single shared pool across all streams.
// Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.

import 'dart:typed_data';
import '../../src/logger.dart';

/// Memory pool manager singleton.
class MemoryPoolManager {
  static MemoryPoolManager? _instance;
  final int bufferSize;
  final int poolSize;
  final List<List<int>> _availableBuffers;
  int _totalBuffers = 0;

  /// Get the singleton instance of MemoryPoolManager.
  static MemoryPoolManager getInstance(
      [int bufferSize = 65536, int poolSize = 100]) {
    _instance ??= MemoryPoolManager._internal(bufferSize, poolSize);
    return _instance!;
  }

  /// Private constructor for singleton pattern.
  MemoryPoolManager._internal(this.bufferSize, this.poolSize)
      : _availableBuffers = [] {
    // Pre-allocate buffers
    for (int i = 0; i < poolSize; i++) {
      Uint8List buffer = Uint8List(bufferSize);
      _availableBuffers.add(buffer);
      _totalBuffers++;
    }

    Logger.info(
        'MemoryPoolManager initialized with $poolSize buffers of $bufferSize bytes');
  }

  /// Acquire a buffer from the pool.
  /// If pool is exhausted, allocates a new buffer dynamically.
  List<int> acquireBuffer() {
    if (_availableBuffers.isNotEmpty) {
      var buffer = _availableBuffers.removeAt(0);
      Logger.debug(
          'Acquired buffer from pool (${_availableBuffers.length} remaining)');
      return buffer;
    } else {
      // Pool exhausted, allocate new buffer
      var buffer = Uint8List(bufferSize);
      _totalBuffers++;
      Logger.debug(
          'Pool exhausted, allocated new buffer (total: $_totalBuffers)');
      return buffer;
    }
  }

  /// Release a buffer back to the pool.
  void releaseBuffer(List<int> buffer) {
    if (buffer.length != bufferSize) {
      Logger.warn(
          'Buffer size mismatch: expected $bufferSize, got ${buffer.length}');
      return;
    }

    // Clear buffer before returning to pool
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }

    // Only return to pool if we haven't exceeded pool size
    if (_availableBuffers.length < poolSize) {
      _availableBuffers.add(buffer);
    }

    Logger.debug(
        'Released buffer to pool (${_availableBuffers.length} available)');
  }

  /// Get the number of available buffers in the pool.
  int getAvailableBuffers() => _availableBuffers.length;

  /// Get the total number of buffers (available + in-use).
  int getTotalBuffers() => poolSize;

  /// Get the buffer size.
  int getBufferSize() => bufferSize;
}
