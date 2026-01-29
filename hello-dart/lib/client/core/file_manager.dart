import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// File I/O operations
class FileManager {
  static const int chunkSize = 65536; // 64KB

  static Future<Uint8List> readChunk(String path, int offset, int size) async {
    final file = File(path);
    final raf = await file.open();
    try {
      await raf.setPosition(offset);
      final data = await raf.read(size);
      return data;
    } finally {
      await raf.close();
    }
  }

  static Future<void> writeChunk(String path, Uint8List data,
      {bool append = true}) async {
    final file = File(path);

    // Create directory if needed
    await file.parent.create(recursive: true);

    if (append && await file.exists()) {
      final raf = await file.open(mode: FileMode.append);
      try {
        await raf.writeFrom(data);
      } finally {
        await raf.close();
      }
    } else {
      await file.writeAsBytes(data);
    }
  }

  static Future<String> computeSha256(String path) async {
    final file = File(path);
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<int> getFileSize(String path) async {
    final file = File(path);
    return await file.length();
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
