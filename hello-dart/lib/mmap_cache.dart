import 'dart:typed_data';
import 'dart:io';
import 'package:logging/logging.dart';

const int DEFAULT_PAGE_SIZE = 64 * 1024 * 1024;
const int MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024;

final _logger = Logger('MmapCache');

class MmapCache {
  String _path;
  Uint8List? _cache;
  int _size;
  bool _isOpen;

  MmapCache(String path)
      : _path = path,
        _size = 0,
        _isOpen = false;

  Future<bool> create(String path, [int initialSize = 0]) async {
    try {
      _logger
          .info('Creating cache file: $path with initial size: $initialSize');

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      _file = await file.open(mode: FileMode.append);
      if (initialSize > 0) {
        _cache = Uint8List(initialSize);
        _size = initialSize;
      } else {
        _cache = Uint8List(0);
        _size = 0;
      }

      _isOpen = true;
      _logger.info('Created cache file: $path with size: $initialSize');
      return true;
    } catch (e) {
      _logger.severe('Error creating file $path: $e');
      return false;
    }
  }

  late RandomAccessFile _file;

  Future<bool> open(String path) async {
    try {
      _logger.info('Opening cache file: $path');

      final file = File(path);
      if (!await file.exists()) {
        _logger.severe('File does not exist: $path');
        return false;
      }

      _file = await file.open(mode: FileMode.append);
      _size = await file.length();
      _cache = await file.readAsBytes();

      _isOpen = true;
      _logger.info('Opened cache file: $path with size: $_size');
      return true;
    } catch (e) {
      _logger.severe('Error opening file $path: $e');
      return false;
    }
  }

  Future<void> close() async {
    if (_isOpen) {
      try {
        await _file.close();
      } catch (e) {
        _logger.warning('Error closing file: $e');
      }
      _cache = null;
      _logger.info('Closed cache file: $_path');
    }
  }

  Future<int> write(int offset, Uint8List data) async {
    try {
      if (!_isOpen) {
        _logger.info('File not open, attempting to open: $_path');
        if (!await open(_path)) {
          return 0;
        }
      }

      final requiredSize = offset + data.length;
      if (requiredSize > _size) {
        if (!await resize(requiredSize)) {
          _logger.severe('Failed to resize file for write operation');
          return 0;
        }
      }

      _file.setPositionSync(offset);
      await _file.writeFrom(data);

      if (_cache != null && _cache!.length >= requiredSize) {
        for (int i = 0; i < data.length; i++) {
          _cache![offset + i] = data[i];
        }
      }

      _logger.info('Wrote ${data.length} bytes to $_path at offset $offset');
      return data.length;
    } catch (e) {
      _logger.severe('Error writing to file $_path: $e');
      return 0;
    }
  }

  Future<Uint8List> read(int offset, int length) async {
    try {
      if (!_isOpen) {
        _logger.info('File not open, attempting to open for reading: $_path');
        if (!await open(_path)) {
          _logger.severe('Failed to open file for reading: $_path');
          return Uint8List(0);
        }
      }

      if (offset >= _size) {
        _logger.info(
            'Read offset $offset at or beyond file size $_size - end of file');
        return Uint8List(0);
      }

      _file.setPositionSync(offset);
      final actualLength =
          length < (_size - offset) ? length : (_size - offset);
      final data = await _file.read(actualLength);

      _logger.info('Read $actualLength bytes from $_path at offset $offset');
      return data;
    } catch (e) {
      _logger.severe('Error reading from file $_path: $e');
      return Uint8List(0);
    }
  }

  int getSize() {
    return _size;
  }

  String getPath() {
    return _path;
  }

  bool isOpen() {
    return _isOpen;
  }

  Future<bool> resize(int newSize) async {
    try {
      if (!_isOpen) {
        _logger.severe('File not open for resize: $_path');
        return false;
      }

      if (newSize == _size) {
        return true;
      }

      await _file.truncate(newSize);
      _size = newSize;

      if (_cache != null) {
        final newCache = Uint8List(newSize);
        final copyLength = _cache!.length < newSize ? _cache!.length : newSize;
        newCache.setRange(0, copyLength, _cache!.sublist(0, copyLength));
        _cache = newCache;
      }

      _logger.info('Resized file $_path to $newSize bytes');
      return true;
    } catch (e) {
      _logger.severe('Error resizing file $_path: $e');
      return false;
    }
  }

  /// Flush all data to disk.
  Future<bool> flush() async {
    try {
      if (!_isOpen) {
        _logger.warning('File not open for flush: $_path');
        return false;
      }

      await _file.flush();
      _logger.info('Flushed file: $_path');
      return true;
    } catch (e) {
      _logger.severe('Error flushing file $_path: $e');
      return false;
    }
  }

  Future<bool> finalize(int finalSize) async {
    try {
      if (!_isOpen) {
        _logger.warning('File not open for finalization: $_path');
        return false;
      }

      if (!await resize(finalSize)) {
        _logger.severe('Failed to resize file during finalization: $_path');
        return false;
      }

      _logger.info('Finalized file: $_path with size: $finalSize');
      return true;
    } catch (e) {
      _logger.severe('Error finalizing file $_path: $e');
      return false;
    }
  }
}
