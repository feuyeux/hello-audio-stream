/**
 * Upload manager for sending files to the server.
 * Handles file upload with chunking and progress reporting.
 * Matches Java UploadManager functionality.
 */

import { WebSocketClient } from "./WebSocketClient";
import { FileManager } from "./FileManager";
import { ChunkManager } from "./ChunkManager";
import { ErrorHandler } from "../util/ErrorHandler";
import { PerformanceMonitor } from "../util/PerformanceMonitor";
import { StreamIdGenerator } from "../util/StreamIdGenerator";

export class UploadManager {
  private wsClient: WebSocketClient;
  private fileManager: FileManager;
  private chunkManager: ChunkManager;
  private errorHandler: ErrorHandler;
  private performanceMonitor: PerformanceMonitor;
  private streamIdGenerator: StreamIdGenerator;

  constructor(
    wsClient: WebSocketClient,
    fileManager: FileManager,
    chunkManager: ChunkManager,
    errorHandler: ErrorHandler,
    performanceMonitor: PerformanceMonitor,
    streamIdGenerator: StreamIdGenerator,
  ) {
    this.wsClient = wsClient;
    this.fileManager = fileManager;
    this.chunkManager = chunkManager;
    this.errorHandler = errorHandler;
    this.performanceMonitor = performanceMonitor;
    this.streamIdGenerator = streamIdGenerator;
  }

  async uploadFile(filePath: string): Promise<string> {
    try {
      // Generate unique stream ID
      const streamId = this.streamIdGenerator.generateShort();
      console.log(`Generated stream ID: ${streamId}`);

      const fileSize = await this.fileManager.getFileSize(filePath);

      // Send START message
      await this.wsClient.sendControlMessage({ type: "START", streamId });

      // Wait for STARTED
      const startResponse = await this.wsClient.receiveControlMessage();
      if (startResponse.type !== "STARTED") {
        throw new Error(`Unexpected response to START: ${startResponse.type}`);
      }

      // Start performance monitoring
      this.performanceMonitor.startUpload();

      // Upload file in chunks
      const uploadChunkSize = this.chunkManager.getUploadChunkSize();
      let offset = 0;
      let bytesSent = 0;
      let lastProgress = 0;

      while (offset < fileSize) {
        const chunkSize = this.chunkManager.getChunkSize(
          fileSize,
          offset,
          uploadChunkSize,
        );
        const chunk = await this.fileManager.readChunk(
          filePath,
          offset,
          chunkSize,
        );

        await this.wsClient.sendBinary(chunk);

        offset += chunk.length;
        bytesSent += chunk.length;

        // Report progress
        const progress = Math.floor((bytesSent * 100) / fileSize);
        if (progress >= lastProgress + 25 && progress <= 100) {
          console.log(
            `Upload progress: ${bytesSent}/${fileSize} bytes (${progress}%)`,
          );
          lastProgress = progress;
        }
      }

      // Ensure 100% is reported
      if (lastProgress < 100) {
        console.log(`Upload progress: ${fileSize}/${fileSize} bytes (100%)`);
      }

      // End performance monitoring
      this.performanceMonitor.endUpload(bytesSent);

      // Send STOP message
      await this.wsClient.sendControlMessage({ type: "STOP", streamId });

      // Wait for STOPPED
      const stopResponse = await this.wsClient.receiveControlMessage();
      if (stopResponse.type !== "STOPPED") {
        throw new Error(`Unexpected response to STOP: ${stopResponse.type}`);
      }

      return streamId;
    } catch (error) {
      this.errorHandler.handleError(error as Error);
      return "";
    }
  }
}
