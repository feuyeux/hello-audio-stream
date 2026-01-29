/**
 * Upload manager for sending files to the server
 */

import { FileManager } from "./FileManager.js";
import { StreamIdGenerator } from "../util/StreamIdGenerator.js";

export class UploadManager {
  constructor(webSocketClient) {
    this.ws = webSocketClient;
    this.fileManager = new FileManager();
    this.streamIdGenerator = new StreamIdGenerator();
  }

  /**
   * Upload a file to the server.
   *
   * @param {string} filePath - Path to the file
   * @param {number} fileSize - Size of the file
   * @param {Function} progressCallback - Optional progress callback
   * @returns {Promise<string>} Stream ID
   */
  async upload(filePath, fileSize, progressCallback = null) {
    // Generate unique stream ID
    const streamId = this.streamIdGenerator.generate();

    // Send START message
    await this.ws.sendControlMessage({ type: "START", streamId });

    // Wait for STARTED
    const startResponse = await this.ws.receiveControlMessage();
    if (startResponse.type !== "STARTED") {
      throw new Error(`Unexpected response to START: ${startResponse.type}`);
    }

    // Upload file in chunks (8KB to avoid WebSocket fragmentation)
    const uploadChunkSize = 8192;
    let offset = 0;
    let bytesSent = 0;

    while (offset < fileSize) {
      const chunkSize = Math.min(uploadChunkSize, fileSize - offset);
      const chunk = await this.fileManager.readChunk(
        filePath,
        offset,
        chunkSize,
      );

      await this.ws.sendBinary(chunk);

      offset += chunk.length;
      bytesSent += chunk.length;

      // Report progress
      if (progressCallback) {
        const progress = Math.floor((bytesSent * 100) / fileSize);
        progressCallback(bytesSent, fileSize, progress);
      }
    }

    // Send STOP message
    await this.ws.sendControlMessage({ type: "STOP", streamId });

    // Wait for STOPPED
    const stopResponse = await this.ws.receiveControlMessage();
    if (stopResponse.type !== "STOPPED") {
      throw new Error(`Unexpected response to STOP: ${stopResponse.type}`);
    }

    return streamId;
  }
}
