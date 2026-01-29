import '../core/file_manager.dart';
import '../../src/types.dart';
import '../../src/logger.dart';

/// File verification module
class Verification {
  static Future<VerificationResult> verify(
      String originalPath, String downloadedPath) async {
    Logger.info('========================================');
    Logger.info('Phase 3: Verification');
    Logger.info('========================================');

    final originalSize = await FileManager.getFileSize(originalPath);
    final downloadedSize = await FileManager.getFileSize(downloadedPath);

    Logger.info('Computing checksums...');
    final originalChecksum = await FileManager.computeSha256(originalPath);
    final downloadedChecksum = await FileManager.computeSha256(downloadedPath);

    Logger.info('Original file:');
    Logger.info('  Size: $originalSize bytes');
    Logger.info('  SHA-256: $originalChecksum');

    Logger.info('Downloaded file:');
    Logger.info('  Size: $downloadedSize bytes');
    Logger.info('  SHA-256: $downloadedChecksum');

    final sizeMatch = originalSize == downloadedSize;
    final checksumMatch =
        originalChecksum.toLowerCase() == downloadedChecksum.toLowerCase();
    final passed = sizeMatch && checksumMatch;

    if (passed) {
      Logger.info('✓ Verification PASSED');
    } else {
      Logger.error('✗ Verification FAILED');
      if (!sizeMatch) {
        Logger.error('  Size mismatch: $originalSize != $downloadedSize');
      }
      if (!checksumMatch) {
        Logger.error('  Checksum mismatch');
      }
    }

    return VerificationResult(
      passed: passed,
      originalSize: originalSize,
      downloadedSize: downloadedSize,
      originalChecksum: originalChecksum,
      downloadedChecksum: downloadedChecksum,
    );
  }
}
