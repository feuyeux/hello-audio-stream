// Memory-mapped cache for efficient file I/O.
// Provides write, read, resize, and finalize operations.
// Matches Python MmapCache functionality.

import 'dart:io';
import '../../src/logger.dart';

// Configuration constants - follows unified mmap specification v2.0.0
const defaultPageSize = 64 * 1024 * 1024; // 64MB
const maxCacheSize = 8 * 1024 * 1024 * 1024; // 8GB
const segmentSize = 1 * 1024 * 1024 * 1024; // 1GB per segment
const batchOperationLimit = 1000; // Max batch operations

/// Memory-mapped cache implementation.
class MemoryMappedCache {
  final String path;
  RandomAccessFile? _file;
  int _size = 0;
  bool _isOpen = false;

  /// Create a new MemoryMappedCache.
  MemoryMappedCache(this.path);

  /// Create a new memory-mapped file.
  Future<bool> create(String filePath, [int initialSize = 0]) async {
    try {
      // Remove existing file
      if (await File(filePath).exists()) {
        await File(filePath).delete();
      }

      // Create and open file
      _file = await File(filePath).open(mode: FileMode.write);

      if (initialSize > 0) {
        // Write zeros to allocate space
        await _file!.setPosition(0);
        await _file!.writeFrom(List.filled(initialSize, 0));
        _size = initialSize;
      } else {
        _size = 0;
      }

      _isOpen = true;
      Logger.debug('Created mmap file: $filePath with size: $initialSize');
      return true;
    } catch (e) {
      Logger.error('Error creating file $filePath: $e');
      return false;
    }
  }

  /// Open an existing memory-mapped file.
  Future<bool> open(String filePath) async {
    try {
      if (!await File(filePath).exists()) {
        Logger.error('File does not exist: $filePath');
        return false;
      }

      _file = await File(filePath).open(mode: FileMode.append);
      _size = await File(filePath).length();
      _isOpen = true;
      Logger.debug('Opened mmap file: $filePath with size: $_size');
      return true;
    } catch (e) {
      Logger.error('Error opening file $filePath: $e');
      return false;
    }
  }

  /// Close the memory-mapped file.
  Future<void> close() async {
    if (_isOpen && _file != null) {
      await _file!.close();
      _file = null;
      _isOpen = false;
    }
  }

  /// Write data to the file (synchronous version).
  int writeSync(int offset, List<int> data) {
    if (!_isOpen || _file == null) {
      int initialSize = offset + data.length;
      File(path).createSync(recursive: true);
      _file = File(path).openSync(mode: FileMode.write);
      _isOpen = true;
      _size = 0;
    }

    int requiredSize = offset + data.length;
    if (requiredSize > _size) {
      if (!resizeSync(requiredSize)) {
        Logger.error('Failed to resize file for write operation');
        return 0;
      }
    }

    try {
      // Seek to offset
      _file!.setPositionSync(offset);

      // Write data
      _file!.writeFromSync(data);
      return data.length;
    } catch (e) {
      Logger.error('Error writing to file $path: $e');
      return 0;
    }
  }

  /// Read data from the file (synchronous version).
  List<int> readSync(int offset, int length) {
    if (!_isOpen || _file == null) {
      if (!File(path).existsSync()) {
        Logger.error('File does not exist: $path');
        return [];
      }
      _file = File(path).openSync(mode: FileMode.read);
      _size = File(path).lengthSync();
      _isOpen = true;
    }

    if (offset >= _size) {
      return [];
    }

    try {
      // Seek to offset
      _file!.setPositionSync(offset);

      // Read data
      int actualLength = length < (_size - offset) ? length : (_size - offset);
      var buffer = _file!.readSync(actualLength);
      Logger.debug('Read ${buffer.length} bytes from $path at offset $offset');
      return buffer;
    } catch (e) {
      Logger.error('Error reading from file $path: $e');
      return [];
    }
  }

  /// Resize the file to a new size (synchronous version).
  bool resizeSync(int newSize) {
    if (!_isOpen) {
      Logger.error('File not open for resize: $path');
      return false;
    }

    if (newSize == _size) {
      return true;
    }

    try {
      if (newSize < _size) {
        // Truncate
        Logger.warn('Truncating file $path to $newSize');
        _file!.truncateSync(newSize);
      } else {
        // Expand - write zeros at the end
        _file!.setPositionSync(_size);
        int extra = newSize - _size;
        _file!.writeFromSync(List.filled(extra, 0));
      }

      _size = newSize;
      Logger.debug('Resized file $path to $newSize bytes');
      return true;
    } catch (e) {
      Logger.error('Error resizing file $path: $e');
      return false;
    }
  }

  Future<int> write(int offset, List<int> data) async {
    if (!_isOpen || _file == null) {
      int initialSize = offset + data.length;
      if (!await create(path, initialSize)) {
        return 0;
      }
    }

    int requiredSize = offset + data.length;
    if (requiredSize > _size) {
      if (!await resize(requiredSize)) {
        Logger.error('Failed to resize file for write operation');
        return 0;
      }
    }

    try {
      // Seek to offset
      await _file!.setPosition(offset);

      // Write data
      await _file!.writeFrom(data);
      return data.length;
    } catch (e) {
      Logger.error('Error writing to file $path: $e');
      return 0;
    }
  }

  /// Read data from the file.
  Future<List<int>> read(int offset, int length) async {
    if (!_isOpen || _file == null) {
      if (!await open(path)) {
        Logger.error('Failed to open file for reading: $path');
        return [];
      }
    }

    if (offset >= _size) {
      return [];
    }

    try {
      // Seek to offset
      await _file!.setPosition(offset);

      // Read data
      int actualLength = length < (_size - offset) ? length : (_size - offset);
      var buffer = await _file!.read(actualLength);
      Logger.debug('Read ${buffer.length} bytes from $path at offset $offset');
      return buffer;
    } catch (e) {
      Logger.error('Error reading from file $path: $e');
      return [];
    }
  }

  /// Get the size of the file.
  int getSize() => _size;

  /// Check if the file is open.
  bool isOpen() => _isOpen;

  /// Resize the file to a new size.
  Future<bool> resize(int newSize) async {
    if (!_isOpen) {
      Logger.error('File not open for resize: $path');
      return false;
    }

    if (newSize == _size) {
      return true;
    }

    try {
      if (newSize < _size) {
        // Truncate
        Logger.warn('Truncating file $path to $newSize');
        await _file!.truncate(newSize);
      } else {
        // Expand - write zeros at the end
        await _file!.setPosition(_size);
        int extra = newSize - _size;
        await _file!.writeFrom(List.filled(extra, 0));
      }

      _size = newSize;
      Logger.debug('Resized file $path to $newSize bytes');
      return true;
    } catch (e) {
      Logger.error('Error resizing file $path: $e');
      return false;
    }
  }

  /// Finalize the file to its final size.
  Future<bool> finalize(int finalSize) async {
    if (!_isOpen) {
      Logger.warn('File not open for finalization: $path');
      return false;
    }

    if (!await resize(finalSize)) {
      Logger.error('Failed to resize file during finalization: $path');
      return false;
    }

    // Sync to disk (file handles auto-sync on close)
    Logger.debug('Finalized file: $path with size: $finalSize');
    return true;
  }
}
