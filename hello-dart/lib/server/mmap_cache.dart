import 'dart:io';

class MmapCache {
  final String path;
  RandomAccessFile? _file;
  int _size = 0;
  bool _open = false;

  MmapCache(this.path);

  bool create() {
    close();
    final f = File(path);
    final dir = f.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    if (f.existsSync()) {
      f.deleteSync();
    }
    _file = f.openSync(mode: FileMode.write);
    _size = 0;
    _open = true;
    return true;
  }

  int write(int offset, List<int> data) {
    if (!_open || _file == null || data.isEmpty) return 0;

    final needed = offset + data.length;
    if (needed > _size) {
      _file!.truncateSync(needed);
      _size = needed;
    }

    _file!.setPositionSync(offset);
    _file!.writeFromSync(data);
    return data.length;
  }

  List<int> read(int offset, int length) {
    if (!_open || _file == null || offset >= _size || length <= 0) return [];

    final actual = length < (_size - offset) ? length : (_size - offset);
    _file!.setPositionSync(offset);
    return _file!.readSync(actual);
  }

  bool finalize(int finalSize) {
    if (!_open || _file == null) return false;
    _file!.truncateSync(finalSize);
    _file!.flushSync();
    _size = finalSize;
    return true;
  }

  void close() {
    if (_file != null) {
      _file!.closeSync();
      _file = null;
    }
    _open = false;
  }

  void delete() {
    close();
    final f = File(path);
    if (f.existsSync()) {
      f.deleteSync();
    }
  }

  int get size => _size;
  bool get isOpen => _open;
}
