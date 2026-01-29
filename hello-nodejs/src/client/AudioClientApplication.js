#!/usr/bin/env node

/**
 * Audio Client Application - Main entry point for Node.js audio stream client.
 * Coordinates client operations including upload, download, and verification.
 */

import { parseArgs } from "../cli.js";
import { WebSocketClient } from "./core/WebSocketClient.js";
import { UploadManager } from "./core/UploadManager.js";
import { DownloadManager } from "./core/DownloadManager.js";
import { FileManager } from "./core/FileManager.js";
import { PerformanceMonitor } from "./util/PerformanceMonitor.js";
import { VerificationModule } from "./util/VerificationModule.js";
import { ErrorHandler } from "./util/ErrorHandler.js";
import * as logger from "../logger.js";
import fs from "fs/promises";
import path from "path";

/**
 * Main client application class.
 */
export class AudioClientApplication {
  constructor(config) {
    this.config = config;
    this.fileManager = new FileManager();
    this.errorHandler = new ErrorHandler(config.verbose);
  }

  /**
   * Run the client application.
   */
  async run() {
    try {
      // Initialize logger
      logger.init(this.config.verbose);

      // Log startup information
      logger.info("Audio Stream Cache Client - Node.js Implementation");
      logger.info(`Server URI: ${this.config.server}`);
      logger.info(`Input file: ${this.config.input}`);
      logger.info(`Output file: ${this.config.output}`);

      // Get input file size
      const fileSize = await this.fileManager.getFileSize(this.config.input);
      logger.info(`Input file size: ${fileSize} bytes`);

      // Initialize performance monitor
      const perf = new PerformanceMonitor(fileSize);

      // Ensure output directory exists
      const outputDir = path.dirname(this.config.output);
      await fs.mkdir(outputDir, { recursive: true });

      // Connect to WebSocket server
      logger.phase("Connecting to Server");
      const ws = new WebSocketClient(this.config.server);
      await ws.connect();
      logger.info("Successfully connected to server");

      try {
        // Upload file
        logger.phase("Starting Upload");
        perf.startUpload();

        const uploadManager = new UploadManager(ws);
        let lastProgress = 0;
        const streamId = await uploadManager.upload(
          this.config.input,
          fileSize,
          (bytesSent, total, progress) => {
            if (progress >= lastProgress + 25 && progress <= 100) {
              logger.info(
                `Upload progress: ${bytesSent}/${total} bytes (${progress}%)`,
              );
              lastProgress = progress;
            }
          },
        );

        perf.endUpload();
        logger.info(
          `Upload completed successfully with stream ID: ${streamId}`,
        );

        // Sleep 2 seconds after upload
        logger.info("Upload successful, sleeping for 2 seconds...");
        await new Promise((resolve) => setTimeout(resolve, 2000));

        // Download file
        logger.phase("Starting Download");
        perf.startDownload();

        const downloadManager = new DownloadManager(ws);
        lastProgress = 0;
        await downloadManager.download(
          streamId,
          this.config.output,
          fileSize,
          (bytesReceived, total, progress) => {
            if (progress >= lastProgress + 25 && progress <= 100) {
              logger.info(
                `Download progress: ${bytesReceived}/${total} bytes (${progress}%)`,
              );
              lastProgress = progress;
            }
          },
        );

        perf.endDownload();
        logger.info("Download completed successfully");

        // Sleep 2 seconds after download
        logger.info("Download successful, sleeping for 2 seconds...");
        await new Promise((resolve) => setTimeout(resolve, 2000));

        // Verify file integrity
        logger.phase("Verifying File Integrity");
        const verificationModule = new VerificationModule();
        const result = await verificationModule.verify(
          this.config.input,
          this.config.output,
        );

        if (result.passed) {
          logger.info("✓ File verification PASSED - Files are identical");
        } else {
          logger.error("✗ File verification FAILED");
          if (result.originalSize !== result.downloadedSize) {
            logger.error(
              `  Reason: File size mismatch (expected ${result.originalSize}, got ${result.downloadedSize})`,
            );
          }
          if (result.originalChecksum !== result.downloadedChecksum) {
            logger.error("  Reason: Checksum mismatch");
          }
          process.exit(1);
        }

        // Generate performance report
        logger.phase("Performance Report");
        const report = perf.getReport();
        logger.info(`Upload Duration: ${report.uploadDurationMs} ms`);
        logger.info(`Upload Throughput: ${report.uploadThroughputMbps} Mbps`);
        logger.info(`Download Duration: ${report.downloadDurationMs} ms`);
        logger.info(
          `Download Throughput: ${report.downloadThroughputMbps} Mbps`,
        );
        logger.info(`Total Duration: ${report.totalDurationMs} ms`);
        logger.info(`Average Throughput: ${report.averageThroughputMbps} Mbps`);

        // Check performance targets
        if (
          report.uploadThroughputMbps < 100.0 ||
          report.downloadThroughputMbps < 200.0
        ) {
          logger.warn(
            "⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)",
          );
        }

        // Disconnect
        await ws.close();
        logger.info("Disconnected from server");

        // Log completion
        logger.phase("Workflow Complete");
        logger.info(
          `Successfully uploaded, downloaded, and verified file: ${this.config.input}`,
        );
      } finally {
        await ws.close();
      }
    } catch (error) {
      this.errorHandler.handle(error, "AudioClientApplication");
      process.exit(1);
    }
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const config = parseArgs();
  const app = new AudioClientApplication(config);
  app.run();
}
