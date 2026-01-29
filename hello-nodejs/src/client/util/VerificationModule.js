/**
 * File verification module for comparing original and downloaded files
 */

import { FileManager } from "../core/FileManager.js";

export class VerificationModule {
  constructor() {
    this.fileManager = new FileManager();
  }

  /**
   * Verify that two files are identical.
   *
   * @param {string} originalPath - Path to original file
   * @param {string} downloadedPath - Path to downloaded file
   * @returns {Promise<Object>} Verification result
   */
  async verify(originalPath, downloadedPath) {
    // Get file sizes
    const originalSize = await this.fileManager.getFileSize(originalPath);
    const downloadedSize = await this.fileManager.getFileSize(downloadedPath);

    // Calculate checksums
    const originalChecksum =
      await this.fileManager.calculateChecksum(originalPath);
    const downloadedChecksum =
      await this.fileManager.calculateChecksum(downloadedPath);

    // Compare
    const passed =
      originalSize === downloadedSize &&
      originalChecksum === downloadedChecksum;

    return {
      passed,
      originalSize,
      downloadedSize,
      originalChecksum,
      downloadedChecksum,
    };
  }
}
