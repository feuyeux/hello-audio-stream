import 'dart:ffi';
import 'dart:io';
import 'package:logging/logging.dart';

const int DEFAULT_PAGE_SIZE = 64 * 1024 * 1024;
const int MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024;

final _logger = Logger('MmapCache');

class MmapCache {
  String _path;
  RandomAccessFile? _file;
  Pointer<Uint8>? _mmap;
  int _size;
  bool _isOpen;

  MmapCache(String path)
      : _path = path,
        _size = 0,
        _isOpen = false;

  Future<bool> create(String path, [int initialSize = 0]) async {
    try {
      _logger.info('Creating mmap file: $path with initial size: $initialSize');

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      _file = await file.open(mode: FileMode.write);
      if (initialSize > 0) {
        await _file!.truncate(initialSize);
        _size = initialSize;
      } else {
        _size = 0;
      }

      if (_size > 0) {
        await _mapFile();
      }

      _isOpen = true;
      _logger.info('Created mmap file: $path with size: $initialSize');
      return true;
    } catch (e) {
      _logger.severe('Error creating file $path: $e');
      return false;
    }
  }

  Future<bool> open(String path) async {
    try {
      _logger.info('Opening mmap file: $path');

      final file = File(path);
      if (!await file.exists()) {
        _logger.severe('File does not exist: $path');
        return false;
      }

      _file = await file.open(mode: FileMode.readWrite);
      _size = await file.length();

      if (_size > 0) {
        await _mapFile();
      }

      _isOpen = true;
      _logger.info('Opened mmap file: $path with size: $_size');
      return true;
    } catch (e) {
      _logger.severe('Error opening file $path: $e');
      return false;
    }
  }

  Future<void> close() async {
    if (_isOpen) {
      await _unmapFile();
      _logger.info('Closed mmap file: $_path');
    }
  }

  Future<int> write(int offset, Uint8List data) async {
    try {
      if (!_isOpen || _mmap == null) {
        final initialSize = offset + data.length;
        if (!await create(_path, initialSize)) {
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

      if (_mmap != null) {
        for (int i = 0; i < data.length; i++) {
          _mmap![offset + i] = data[i];
        }
      }

      _logger.info('Wrote ${data.length} bytes to $_path at offset $offset');
      return data.length;
    } catch (e) {
      _logger.severe('Error writing to mapped file $_path: $e');
      return 0;
    }
  }

  Future<Uint8List> read(int offset, int length) async {
    try {
      if (!_isOpen || _mmap == null) {
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

      final actualLength =
          length < (_size - offset) ? length : (_size - offset);
      final data = Uint8List(actualLength);

      if (_mmap != null) {
        for (int i = 0; i < actualLength; i++) {
          data[i] = _mmap![offset + i];
        }
      }

      _logger.info('Read $actualLength bytes from $_path at offset $offset');
      return data;
    } catch (e) {
      _logger.severe('Error reading from mapped file $_path: $e');
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

      await _unmapFile();
      await _file!.truncate(newSize);
      _size = newSize;

      if (_size > 0) {
        await _mapFile();
      }

      _logger.info('Resized and remapped file $_path to $newSize bytes');
      return true;
    } catch (e) {
      _logger.severe('Error resizing file $_path: $e');
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

  Future<void> _mapFile() async {
    try {
      if (_file != null && _size > 0) {
        final data = await _file!.read(_size);
        _mmap = data.cast<Uint8>();
        _logger.info('Successfully mapped file: $_path ($_size bytes)');
      }
    } catch (e) {
      _logger.severe('Error mapping file $_path: $e');
      rethrow;
    }
  }

  Future<void> _unmapFile() async {
    _mmap = null;

    if (_file != null) {
      await _file!.close();
      _file = null;
    }

    _isOpen = false;
  }
}
