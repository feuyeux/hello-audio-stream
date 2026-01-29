/**
 * Download manager for receiving files from the server.
 * Handles file download with chunking and progress reporting.
 * Matches Java DownloadManager functionality.
 */

import { WebSocketClient } from "./WebSocketClient";
import { FileManager } from "./FileManager";
import { ChunkManager } from "./ChunkManager";
import { ErrorHandler } from "../util/ErrorHandler";

export class DownloadManager {
  private wsClient: WebSocketClient;
  private fileManager: FileManager;
  private chunkManager: ChunkManager;
  private errorHandler: ErrorHandler;
  private lastError: string = "";
  private bytesDownloaded: number = 0;

  constructor(
    wsClient: WebSocketClient,
    fileManager: FileManager,
    chunkManager: ChunkManager,
    errorHandler: ErrorHandler,
  ) {
    this.wsClient = wsClient;
    this.fileManager = fileManager;
    this.chunkManager = chunkManager;
    this.errorHandler = errorHandler;
  }

  async downloadFile(
    streamId: string,
    outputPath: string,
    fileSize: number,
  ): Promise<boolean> {
    try {
      let offset = 0;
      this.bytesDownloaded = 0;
      let lastProgress = 0;
      let isFirstChunk = true;

      const chunkSize = this.chunkManager.getDefaultChunkSize();

      while (offset < fileSize) {
        // Calculate how much data we still need
        const requestSize = this.chunkManager.getChunkSize(
          fileSize,
          offset,
          chunkSize,
        );

        // Send GET message
        await this.wsClient.sendControlMessage({
          type: "GET",
          streamId,
          offset,
          length: requestSize,
        });

        // Receive binary data
        const data = await this.wsClient.receiveBinary();

        if (data.length === 0) {
          throw new Error(`No data received for offset ${offset}`);
        }

        // Write to file
        await this.fileManager.writeChunk(outputPath, data, !isFirstChunk);

        isFirstChunk = false;
        offset += data.length;
        this.bytesDownloaded += data.length;

        // Report progress
        const progress = Math.floor((this.bytesDownloaded * 100) / fileSize);
        if (progress >= lastProgress + 25 && progress <= 100) {
          console.log(
            `Download progress: ${this.bytesDownloaded}/${fileSize} bytes (${progress}%)`,
          );
          lastProgress = progress;
        }
      }

      // Ensure 100% is reported
      if (lastProgress < 100) {
        console.log(`Download progress: ${fileSize}/${fileSize} bytes (100%)`);
      }

      return true;
    } catch (error) {
      this.lastError = (error as Error).message;
      this.errorHandler.handleError(error as Error);
      return false;
    }
  }

  getLastError(): string {
    return this.lastError;
  }

  getBytesDownloaded(): number {
    return this.bytesDownloaded;
  }
}
