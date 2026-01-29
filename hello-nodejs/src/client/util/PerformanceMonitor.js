/**
 * Performance monitoring for tracking upload/download metrics
 */

export class PerformanceMonitor {
  constructor(fileSize) {
    this.fileSize = fileSize;
    this.uploadStartTime = 0;
    this.uploadEndTime = 0;
    this.downloadStartTime = 0;
    this.downloadEndTime = 0;
  }

  startUpload() {
    this.uploadStartTime = performance.now();
  }

  endUpload() {
    this.uploadEndTime = performance.now();
  }

  startDownload() {
    this.downloadStartTime = performance.now();
  }

  endDownload() {
    this.downloadEndTime = performance.now();
  }

  getReport() {
    const uploadDurationMs = Math.round(
      this.uploadEndTime - this.uploadStartTime,
    );
    const downloadDurationMs = Math.round(
      this.downloadEndTime - this.downloadStartTime,
    );
    const totalDurationMs = uploadDurationMs + downloadDurationMs;

    // Calculate throughput in Mbps
    const fileSizeMb = (this.fileSize * 8) / (1024 * 1024);
    const uploadThroughputMbps =
      uploadDurationMs > 0 ? (fileSizeMb / uploadDurationMs) * 1000 : 0;
    const downloadThroughputMbps =
      downloadDurationMs > 0 ? (fileSizeMb / downloadDurationMs) * 1000 : 0;
    const averageThroughputMbps =
      totalDurationMs > 0 ? ((fileSizeMb * 2) / totalDurationMs) * 1000 : 0;

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
