import 'dart:io';
import 'mmap_cache.dart';

class Stream {
  final String id;
  final MmapCache cache;
  final double created;
  int offset = 0;
  double lastAccess;
  String status = 'UPLOADING';

  Stream(this.id, this.cache, this.created) : lastAccess = created;

  void touch() {
    lastAccess = DateTime.now().millisecondsSinceEpoch / 1000.0;
  }
}

class StreamManager {
  final Map<String, Stream> _streams = {};
  final String cacheDir;
  final int maxStreams;
  final double _maxIdleSeconds;
  final double _maxUploadingSeconds;

  StreamManager({
    this.cacheDir = 'cache',
    this.maxStreams = 1000,
    double maxIdleHours = 24.0,
    double maxUploadingHours = 1.0,
  })  : _maxIdleSeconds = maxIdleHours * 3600,
        _maxUploadingSeconds = maxUploadingHours * 3600 {
    Directory(cacheDir).createSync(recursive: true);
  }

  bool create(String streamId) {
    if (_streams.containsKey(streamId)) return false;
    if (_streams.length >= maxStreams) return false;

    final path = '$cacheDir/$streamId.cache';
    final cache = MmapCache(path);
    if (!cache.create()) return false;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _streams[streamId] = Stream(streamId, cache, now);
    return true;
  }

  bool write(String streamId, List<int> data) {
    final stream = _streams[streamId];
    if (stream == null || stream.status != 'UPLOADING') return false;

    final written = stream.cache.write(stream.offset, data);
    if (written <= 0) return false;

    stream.offset += written;
    stream.touch();
    return true;
  }

  bool complete(String streamId) {
    final stream = _streams[streamId];
    if (stream == null || stream.status != 'UPLOADING') return false;

    if (!stream.cache.finalize(stream.offset)) return false;

    stream.status = 'READY';
    stream.touch();
    return true;
  }

  List<int> read(String streamId, int offset, int length) {
    final stream = _streams[streamId];
    if (stream == null) return [];

    stream.touch();
    return stream.cache.read(offset, length);
  }

  bool delete(String streamId) {
    final stream = _streams[streamId];
    if (stream == null) return false;

    stream.cache.delete();
    _streams.remove(streamId);
    return true;
  }

  void markError(String streamId) {
    final stream = _streams[streamId];
    if (stream != null && stream.status == 'UPLOADING') {
      stream.status = 'ERROR';
    }
  }

  Map<String, dynamic>? statusOf(String streamId) {
    final stream = _streams[streamId];
    if (stream == null) return null;

    stream.touch();
    return {'status': stream.status, 'size': stream.offset};
  }

  List<String> list() => _streams.keys.toList();

  int cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    var removed = 0;
    final toRemove = <String>[];

    for (final entry in _streams.entries) {
      final idle = now - entry.value.lastAccess;
      final shouldRemove = switch (entry.value.status) {
        'UPLOADING' => idle > _maxUploadingSeconds,
        'ERROR' => true,
        _ => idle > _maxIdleSeconds,
      };
      if (shouldRemove) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      delete(id);
      removed++;
    }
    return removed;
  }

  Map<String, int> stats() {
    return {
      'total': _streams.length,
      'uploading': _streams.values.where((s) => s.status == 'UPLOADING').length,
      'ready': _streams.values.where((s) => s.status == 'READY').length,
      'error': _streams.values.where((s) => s.status == 'ERROR').length,
    };
  }
}
