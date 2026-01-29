package client.util

import client.core.FileManager
import Logger
import VerificationResult

/**
 * File verification module
 */
object VerificationModule {
    fun verify(originalPath: String, downloadedPath: String): VerificationResult {
        Logger.info("========================================")
        Logger.info("Phase 3: Verification")
        Logger.info("========================================")
        
        val originalSize = FileManager.getFileSize(originalPath)
        val downloadedSize = FileManager.getFileSize(downloadedPath)
        
        Logger.info("Computing checksums...")
        val originalChecksum = FileManager.computeSha256(originalPath)
        val downloadedChecksum = FileManager.computeSha256(downloadedPath)
        
        Logger.info("Original file:")
        Logger.info("  Size: $originalSize bytes")
        Logger.info("  SHA-256: $originalChecksum")
        
        Logger.info("Downloaded file:")
        Logger.info("  Size: $downloadedSize bytes")
        Logger.info("  SHA-256: $downloadedChecksum")
        
        val sizeMatch = originalSize == downloadedSize
        val checksumMatch = originalChecksum.equals(downloadedChecksum, ignoreCase = true)
        val passed = sizeMatch && checksumMatch
        
        if (passed) {
            Logger.info("✓ Verification PASSED")
        } else {
            Logger.error("✗ Verification FAILED")
            if (!sizeMatch) {
                Logger.error("  Size mismatch: $originalSize != $downloadedSize")
            }
            if (!checksumMatch) {
                Logger.error("  Checksum mismatch")
            }
        }
        
        return VerificationResult(
            passed = passed,
            originalSize = originalSize,
            downloadedSize = downloadedSize,
            originalChecksum = originalChecksum,
            downloadedChecksum = downloadedChecksum
        )
    }
}
