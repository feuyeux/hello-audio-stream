/**
 * Verification module for comparing original and downloaded files.
 * Performs file size and checksum verification.
 * Matches Java VerificationModule functionality.
 */

import { FileManager } from "../core/FileManager";

export class VerificationReport {
  private passed: boolean;
  private originalSize: number;
  private downloadedSize: number;
  private originalChecksum: string;
  private downloadedChecksum: string;

  constructor(
    passed: boolean,
    originalSize: number,
    downloadedSize: number,
    originalChecksum: string,
    downloadedChecksum: string,
  ) {
    this.passed = passed;
    this.originalSize = originalSize;
    this.downloadedSize = downloadedSize;
    this.originalChecksum = originalChecksum;
    this.downloadedChecksum = downloadedChecksum;
  }

  isVerificationPassed(): boolean {
    return this.passed;
  }

  printReport(): void {
    console.log("\n=== Verification Report ===");
    console.log(`Original size: ${this.originalSize} bytes`);
    console.log(`Downloaded size: ${this.downloadedSize} bytes`);
    console.log(`Original checksum (SHA-256): ${this.originalChecksum}`);
    console.log(`Downloaded checksum (SHA-256): ${this.downloadedChecksum}`);

    if (this.passed) {
      console.log("✓ File verification PASSED - Files are identical");
    } else {
      console.log("✗ File verification FAILED");
      if (this.originalSize !== this.downloadedSize) {
        console.log(`  Reason: File size mismatch`);
      }
      if (this.originalChecksum !== this.downloadedChecksum) {
        console.log("  Reason: Checksum mismatch");
      }
    }
    console.log("===========================\n");
  }
}

export class VerificationModule {
  private fileManager: FileManager;

  constructor() {
    this.fileManager = new FileManager();
  }

  async generateReport(
    originalPath: string,
    downloadedPath: string,
  ): Promise<VerificationReport> {
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

    return new VerificationReport(
      passed,
      originalSize,
      downloadedSize,
      originalChecksum,
      downloadedChecksum,
    );
  }
}
