/**
 * Performance monitor for tracking upload/download metrics.
 * Calculates throughput and duration statistics.
 * Matches Java PerformanceMonitor functionality.
 */

export interface PerformanceMetrics {
  uploadDurationMs: number;
  uploadThroughputMbps: number;
  downloadDurationMs: number;
  downloadThroughputMbps: number;
  totalDurationMs: number;
  averageThroughputMbps: number;
}

export class PerformanceMonitor {
  private fileSize: number;
  private uploadStartTime: number = 0;
  private uploadEndTime: number = 0;
  private downloadStartTime: number = 0;
  private downloadEndTime: number = 0;
  private uploadBytes: number = 0;
  private downloadBytes: number = 0;

  constructor(fileSize: number) {
    this.fileSize = fileSize;
  }

  startUpload(): void {
    this.uploadStartTime = performance.now();
  }

  endUpload(bytes: number = this.fileSize): void {
    this.uploadEndTime = performance.now();
    this.uploadBytes = bytes;
  }

  startDownload(): void {
    this.downloadStartTime = performance.now();
  }

  endDownload(bytes: number = this.fileSize): void {
    this.downloadEndTime = performance.now();
    this.downloadBytes = bytes;
  }

  getMetrics(): PerformanceMetrics {
    const uploadDurationMs = Math.round(
      this.uploadEndTime - this.uploadStartTime,
    );
    const downloadDurationMs = Math.round(
      this.downloadEndTime - this.downloadStartTime,
    );
    const totalDurationMs = uploadDurationMs + downloadDurationMs;

    // Calculate throughput in Mbps
    const uploadSizeMb = (this.uploadBytes * 8) / (1024 * 1024); // Convert bytes to megabits
    const downloadSizeMb = (this.downloadBytes * 8) / (1024 * 1024);

    const uploadThroughputMbps =
      uploadDurationMs > 0 ? (uploadSizeMb / uploadDurationMs) * 1000 : 0;
    const downloadThroughputMbps =
      downloadDurationMs > 0 ? (downloadSizeMb / downloadDurationMs) * 1000 : 0;
    const averageThroughputMbps =
      totalDurationMs > 0
        ? ((uploadSizeMb + downloadSizeMb) / totalDurationMs) * 1000
        : 0;

    return {
      uploadDurationMs,
      uploadThroughputMbps: parseFloat(uploadThroughputMbps.toFixed(2)),
      downloadDurationMs,
      downloadThroughputMbps: parseFloat(downloadThroughputMbps.toFixed(2)),
      totalDurationMs,
      averageThroughputMbps: parseFloat(averageThroughputMbps.toFixed(2)),
    };
  }
}
