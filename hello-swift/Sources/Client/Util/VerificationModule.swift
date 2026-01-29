import Foundation
import AudioStreamCommon

/// File verification module
class VerificationModule {
    static func verify(originalPath: String, downloadedPath: String) throws -> VerificationResult {
        Logger.info("========================================")
        Logger.info("Phase 3: Verification")
        Logger.info("========================================")
        
        let originalSize = try AudioFileManager.getFileSize(path: originalPath)
        let downloadedSize = try AudioFileManager.getFileSize(path: downloadedPath)
        
        Logger.info("Computing checksums...")
        let originalChecksum = try AudioFileManager.computeSha256(path: originalPath)
        let downloadedChecksum = try AudioFileManager.computeSha256(path: downloadedPath)
        
        Logger.info("Original file:")
        Logger.info("  Size: \(originalSize) bytes")
        Logger.info("  SHA-256: \(originalChecksum)")
        
        Logger.info("Downloaded file:")
        Logger.info("  Size: \(downloadedSize) bytes")
        Logger.info("  SHA-256: \(downloadedChecksum)")
        
        let sizeMatch = originalSize == downloadedSize
        let checksumMatch = originalChecksum.lowercased() == downloadedChecksum.lowercased()
        let passed = sizeMatch && checksumMatch
        
        if passed {
            Logger.info("✓ Verification PASSED")
        } else {
            Logger.error("✗ Verification FAILED")
            if !sizeMatch {
                Logger.error("  Size mismatch: \(originalSize) != \(downloadedSize)")
            }
            if !checksumMatch {
                Logger.error("  Checksum mismatch")
            }
        }
        
        return VerificationResult(
            passed: passed,
            originalSize: originalSize,
            downloadedSize: downloadedSize,
            originalChecksum: originalChecksum,
            downloadedChecksum: downloadedChecksum
        )
    }
}
