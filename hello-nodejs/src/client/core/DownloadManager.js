/**
 * Download manager for receiving files from the server
 */

import { FileManager, CHUNK_SIZE } from "./FileManager.js";

export class DownloadManager {
  constructor(webSocketClient) {
    this.ws = webSocketClient;
    this.fileManager = new FileManager();
  }

  /**
   * Download a file from the server.
   *
   * @param {string} streamId - Stream ID to download
   * @param {string} outputPath - Path to save the file
   * @param {number} fileSize - Expected file size
   * @param {Function} progressCallback - Optional progress callback
   */
  async download(streamId, outputPath, fileSize, progressCallback = null) {
    let offset = 0;
    let bytesReceived = 0;
    let isFirstChunk = true;

    while (offset < fileSize) {
      const remainingBytes = fileSize - offset;
      const chunkSize = Math.min(CHUNK_SIZE, remainingBytes);

      // Send GET message
      await this.ws.sendControlMessage({
        type: "GET",
        streamId,
        offset,
        length: chunkSize,
      });

      // Receive binary data
      const data = await this.ws.receiveBinary();

      if (data.length === 0) {
        throw new Error(`No data received for offset ${offset}`);
      }

      // Write to file
      await this.fileManager.writeChunk(outputPath, data, !isFirstChunk);

      isFirstChunk = false;
      offset += data.length;
      bytesReceived += data.length;

      // Report progress
      if (progressCallback) {
        const progress = Math.floor((bytesReceived * 100) / fileSize);
        progressCallback(bytesReceived, fileSize, progress);
      }
    }
  }
}
