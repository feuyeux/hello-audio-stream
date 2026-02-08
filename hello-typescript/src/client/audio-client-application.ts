#!/usr/bin/env node
/**
 * Audio Client Application - TypeScript Implementation
 * Main entry point for the audio streaming client.
 * Performs upload, download, and file verification operations.
 * Matches Java AudioClientApplication structure and functionality.
 */

import { WebSocketClient } from "./core/WebSocketClient";
import { UploadManager } from "./core/UploadManager";
import { DownloadManager } from "./core/DownloadManager";
import { FileManager } from "./core/FileManager";
import { ChunkManager } from "./core/ChunkManager";
import { PerformanceMonitor } from "./util/PerformanceMonitor";
import { VerificationModule } from "./util/VerificationModule";
import { ErrorHandler } from "./util/ErrorHandler";
import { StreamIdGenerator } from "./util/StreamIdGenerator";
import * as fs from "fs/promises";
import * as path from "path";
import { Command } from "commander";

interface Config {
  server: string;
  input: string;
  output: string;
  verbose: boolean;
}

class AudioClientApplication {
  private config: Config;

  constructor(config: Config) {
    this.config = config;
  }

  async run(): Promise<void> {
    console.log("\n=== Starting Audio Stream Test ===");
    console.log(`Input File: ${this.config.input}`);
    console.log(`Output File: ${path.basename(this.config.output)}`);
    console.log("================================\n");

    // Initialize components
    const wsClient = new WebSocketClient(this.config.server);
    const fileManager = new FileManager();
    const chunkManager = new ChunkManager();
    const errorHandler = new ErrorHandler();
    const streamIdGenerator = new StreamIdGenerator();

    const fileSize = await fileManager.getFileSize(this.config.input);
    const performanceMonitor = new PerformanceMonitor(fileSize);

    const uploadManager = new UploadManager(
      wsClient,
      fileManager,
      chunkManager,
      errorHandler,
      performanceMonitor,
      streamIdGenerator,
    );

    const downloadManager = new DownloadManager(
      wsClient,
      fileManager,
      chunkManager,
      errorHandler,
    );

    const verificationModule = new VerificationModule();

    const operationStartTime = Date.now();

    try {
      // Ensure output directory exists
      const outputDir = path.dirname(this.config.output);
      await fs.mkdir(outputDir, { recursive: true });

      // Connect to server
      console.log("Connecting to server...");
      await wsClient.connect();
      console.log("Successfully connected to server\n");

      // 1. Upload file
      console.log("[1/3] Uploading file...");
      const uploadStreamId = await uploadManager.uploadFile(this.config.input);

      if (!uploadStreamId) {
        throw new Error("Upload failed");
      }

      const uploadMetrics = performanceMonitor.getMetrics();
      console.log(
        `Upload result: streamId=${uploadStreamId}, duration=${uploadMetrics.uploadDurationMs}ms, throughput=${uploadMetrics.uploadThroughputMbps.toFixed(2)} Mbps\n`,
      );

      // 2. Sleep for 2 seconds
      console.log("Upload successful, sleeping for 2 seconds...");
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // 3. Download file
      console.log("[2/3] Downloading file...");
      performanceMonitor.startDownload();
      const downloadSuccess = await downloadManager.downloadFile(
        uploadStreamId,
        this.config.output,
        fileSize,
      );

      if (!downloadSuccess) {
        throw new Error(`Download failed: ${downloadManager.getLastError()}`);
      }

      const downloadedBytes = downloadManager.getBytesDownloaded();
      performanceMonitor.endDownload(downloadedBytes);

      const downloadMetrics = performanceMonitor.getMetrics();
      console.log(
        `Download result: success=${downloadSuccess}, duration=${downloadMetrics.downloadDurationMs}ms, throughput=${downloadMetrics.downloadThroughputMbps.toFixed(2)} Mbps\n`,
      );

      // 4. Sleep for 2 seconds
      console.log("Download successful, sleeping for 2 seconds...");
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // 5. Verify files
      console.log("[3/3] Comparing files...");
      const verificationResult = await verificationModule.generateReport(
        this.config.input,
        this.config.output,
      );
      verificationResult.printReport();

      // Close connection
      await wsClient.close();

      const operationEndTime = Date.now();
      const totalDurationMs = operationEndTime - operationStartTime;

      const isSuccess = verificationResult.isVerificationPassed();
      const metrics = performanceMonitor.getMetrics();

      console.log("\n=== Operation Summary ===");
      console.log(`Stream ID: ${uploadStreamId}`);
      console.log(
        `Total Duration: ${totalDurationMs} ms (${(totalDurationMs / 1000).toFixed(2)} seconds)`,
      );
      console.log(`Upload Time: ${metrics.uploadDurationMs} ms`);
      console.log(`Download Time: ${metrics.downloadDurationMs} ms`);
      console.log(
        `Upload Throughput: ${metrics.uploadThroughputMbps.toFixed(2)} Mbps`,
      );
      console.log(
        `Download Throughput: ${metrics.downloadThroughputMbps.toFixed(2)} Mbps`,
      );
      console.log(`Content Match: ${isSuccess}`);
      console.log(`Overall Result: ${isSuccess ? "SUCCESS" : "FAILED"}`);
      console.log("==========================\n");

      if (isSuccess) {
        console.log("Audio stream test completed successfully!");
        process.exit(0);
      } else {
        console.error("Audio stream test failed: Files do not match!");
        process.exit(1);
      }
    } catch (error) {
      console.error("Application execution failed:", error);
      await wsClient.close();
      process.exit(1);
    }
  }
}

function parseArgs(): Config {
  const program = new Command();

  program
    .name("audio-stream-client")
    .description("Audio Stream Cache Client - TypeScript Implementation")
    .version("1.0.0")
    .requiredOption("-i, --input <file>", "Input audio file path")
    .option(
      "-s, --server <uri>",
      "WebSocket server URI",
      "ws://localhost:8080/audio",
    )
    .option(
      "-o, --output <file>",
      "Output file path (auto-generated if not specified)",
    )
    .option("-v, --verbose", "Enable verbose logging", false)
    .parse();

  const options = program.opts();

  // Generate output path if not provided
  let outputPath = options.output;
  if (!outputPath) {
    const timestamp = new Date()
      .toISOString()
      .replace(/[:.]/g, "-")
      .slice(0, 19);
    const basename = path.basename(options.input);
    outputPath = path.join(
      "audio",
      "output",
      `output-${timestamp}-${basename}`,
    );
  }

  return {
    server: options.server,
    input: options.input,
    output: outputPath,
    verbose: options.verbose,
  };
}

async function main(): Promise<void> {
  const config = parseArgs();
  const app = new AudioClientApplication(config);
  await app.run();
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
