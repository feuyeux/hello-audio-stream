import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:crypto/crypto.dart';

const _chunkSize = 8192;
const _readSize = 65536;

class Client {
  final String serverUri;
  final String inputFile;
  final String outputDir;

  Client(this.serverUri, this.inputFile, this.outputDir);

  Future<void> run() async {
    Directory(outputDir).createSync(recursive: true);

    final ws = await WebSocket.connect(serverUri);
    final queue = StreamQueue<dynamic>(ws);

    try {
      // Wait for CONNECTED
      final connRaw = await queue.next;
      final connMsg = jsonDecode(connRaw as String) as Map<String, dynamic>;
      print('Connected: ${connMsg['streamId']}');

      // Upload
      final streamId = await _upload(ws, queue);

      // Get status
      ws.add(jsonEncode({'command': 'GET_STATUS', 'streamId': streamId}));
      final statusRaw = await queue.next;
      final statusMsg = jsonDecode(statusRaw as String) as Map<String, dynamic>;
      final fileSize = statusMsg['size'] as int;
      print('Status: ${statusMsg['status']}, size: $fileSize');

      // Download
      final fileName = inputFile.split(Platform.pathSeparator).last.split('/').last;
      final outputPath = '$outputDir${Platform.pathSeparator}$fileName';
      await _download(ws, queue, streamId, outputPath, fileSize);

      // Verify
      _verify(outputPath);

      // Close stream
      ws.add(jsonEncode({'command': 'CLOSE', 'streamId': streamId}));
      await queue.next;
      print('Stream closed');
    } finally {
      await queue.cancel();
      await ws.close();
    }
  }

  Future<String> _upload(WebSocket ws, StreamQueue<dynamic> queue) async {
    final file = File(inputFile);
    final fileSize = file.lengthSync();
    final streamId = 'stream-${_randomHex(8)}';

    print('========================================');
    print('Phase 1: Upload');
    print('========================================');
    print('Stream: $streamId, size: $fileSize');

    // CREATE
    ws.add(jsonEncode({'command': 'CREATE', 'streamId': streamId}));
    final createdRaw = await queue.next;
    final created = jsonDecode(createdRaw as String) as Map<String, dynamic>;
    if (created['command'] != 'CREATED') {
      throw Exception('Expected CREATED, got: ${created['command']}');
    }

    // Send binary data
    final handle = file.openSync();
    var sent = 0;
    var lastReport = 0;
    try {
      while (sent < fileSize) {
        final size = min(_chunkSize, fileSize - sent);
        final chunk = handle.readSync(size);
        ws.add(chunk);
        sent += chunk.length;

        final pct = (sent * 100) ~/ fileSize;
        if (pct >= lastReport + 25) {
          print('  Upload: $pct% ($sent / $fileSize)');
          lastReport = (pct ~/ 25) * 25;
        }
      }
    } finally {
      handle.closeSync();
    }
    print('  Upload: 100% ($fileSize / $fileSize)');

    // COMPLETE
    ws.add(jsonEncode({'command': 'COMPLETE'}));
    final completedRaw = await queue.next;
    final completed = jsonDecode(completedRaw as String) as Map<String, dynamic>;
    if (completed['command'] != 'COMPLETED') {
      throw Exception('Expected COMPLETED, got: ${completed['command']}');
    }
    print('Upload completed');

    return streamId;
  }

  Future<void> _download(WebSocket ws, StreamQueue<dynamic> queue,
      String streamId, String outputPath, int fileSize) async {
    print('========================================');
    print('Phase 2: Download');
    print('========================================');
    print('Output: $outputPath');

    final file = File(outputPath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    final handle = file.openSync(mode: FileMode.write);
    var offset = 0;
    var lastReport = 0;

    try {
      while (offset < fileSize) {
        final length = min(_readSize, fileSize - offset);
        ws.add(jsonEncode({
          'command': 'READ',
          'streamId': streamId,
          'offset': offset,
          'length': length,
        }));

        final data = await queue.next;
        List<int> bytes;
        if (data is Uint8List) {
          bytes = data;
        } else if (data is List<int>) {
          bytes = data;
        } else {
          throw Exception('Expected binary data at offset $offset');
        }

        final actual = min(bytes.length, fileSize - offset);
        handle.writeFromSync(bytes, 0, actual);
        offset += actual;

        final pct = (offset * 100) ~/ fileSize;
        if (pct >= lastReport + 25) {
          print('  Download: $pct% ($offset / $fileSize)');
          lastReport = (pct ~/ 25) * 25;
        }
      }
    } finally {
      handle.closeSync();
    }
    print('  Download: 100% ($fileSize / $fileSize)');
    print('Download completed');
  }

  void _verify(String outputPath) {
    print('========================================');
    print('Phase 3: Verification');
    print('========================================');

    final origSize = File(inputFile).lengthSync();
    final dlSize = File(outputPath).lengthSync();
    final origMd5 = md5.convert(File(inputFile).readAsBytesSync()).toString();
    final dlMd5 = md5.convert(File(outputPath).readAsBytesSync()).toString();

    print('Original:   size=$origSize, md5=$origMd5');
    print('Downloaded: size=$dlSize, md5=$dlMd5');

    if (origSize == dlSize && origMd5 == dlMd5) {
      print('Verification PASSED');
    } else {
      print('Verification FAILED');
    }
  }

  static String _randomHex(int length) {
    final rng = Random.secure();
    return List.generate(length, (_) => rng.nextInt(16).toRadixString(16)).join();
  }
}

void main(List<String> arguments) async {
  var serverUri = 'ws://localhost:8080';
  var inputFile = '../audio/input/hello.opus';
  var outputDir = 'audio/output';

  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--server' && i + 1 < arguments.length) {
      serverUri = arguments[i + 1];
      i++;
    } else if (arguments[i] == '--input' && i + 1 < arguments.length) {
      inputFile = arguments[i + 1];
      i++;
    } else if (arguments[i] == '--output' && i + 1 < arguments.length) {
      outputDir = arguments[i + 1];
      i++;
    }
  }

  final client = Client(serverUri, inputFile, outputDir);
  await client.run();
}
