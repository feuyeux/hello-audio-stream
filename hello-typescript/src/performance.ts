/**
 * Performance monitoring for tracking upload/download metrics
 */

import { PerformanceReport } from "./types";

export class PerformanceMonitor {
  private fileSize: number;
  private uploadStartTime: number = 0;
  private uploadEndTime: number = 0;
  private downloadStartTime: number = 0;
  private downloadEndTime: number = 0;

  constructor(fileSize: number) {
    this.fileSize = fileSize;
  }

  startUpload(): void {
    this.uploadStartTime = performance.now();
  }

  endUpload(): void {
    this.uploadEndTime = performance.now();
  }

  startDownload(): void {
    this.downloadStartTime = performance.now();
  }

  endDownload(): void {
    this.downloadEndTime = performance.now();
  }

  getReport(): PerformanceReport {
    const uploadDurationMs = Math.round(
      this.uploadEndTime - this.uploadStartTime,
    );
    const downloadDurationMs = Math.round(
      this.downloadEndTime - this.downloadStartTime,
    );
    const totalDurationMs = uploadDurationMs + downloadDurationMs;

    // Calculate throughput in Mbps
    const fileSizeMb = (this.fileSize * 8) / (1024 * 1024); // Convert bytes to megabits
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
