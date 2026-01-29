/**
 * File manager for file I/O operations
 */

import fs from "fs/promises";
import crypto from "crypto";

export const CHUNK_SIZE = 65536; // 64KB

export class FileManager {
  /**
   * Get file size.
   *
   * @param {string} filePath - Path to the file
   * @returns {Promise<number>} File size in bytes
   */
  async getFileSize(filePath) {
    const stats = await fs.stat(filePath);
    return stats.size;
  }

  /**
   * Read a chunk from a file.
   *
   * @param {string} filePath - Path to the file
   * @param {number} offset - Offset to read from
   * @param {number} length - Number of bytes to read
   * @returns {Promise<Buffer>} Data read
   */
  async readChunk(filePath, offset, length) {
    const fileHandle = await fs.open(filePath, "r");
    try {
      const buffer = Buffer.alloc(length);
      const { bytesRead } = await fileHandle.read(buffer, 0, length, offset);
      return buffer.slice(0, bytesRead);
    } finally {
      await fileHandle.close();
    }
  }

  /**
   * Write a chunk to a file.
   *
   * @param {string} filePath - Path to the file
   * @param {Buffer} data - Data to write
   * @param {boolean} append - Whether to append or overwrite
   */
  async writeChunk(filePath, data, append) {
    const flag = append ? "a" : "w";
    await fs.writeFile(filePath, data, { flag });
  }

  /**
   * Calculate SHA-256 checksum of a file.
   *
   * @param {string} filePath - Path to the file
   * @returns {Promise<string>} Hex-encoded checksum
   */
  async calculateChecksum(filePath) {
    const fileHandle = await fs.open(filePath, "r");
    const hash = crypto.createHash("sha256");

    try {
      const buffer = Buffer.alloc(CHUNK_SIZE);
      let bytesRead;

      do {
        const result = await fileHandle.read(buffer, 0, CHUNK_SIZE, null);
        bytesRead = result.bytesRead;
        if (bytesRead > 0) {
          hash.update(buffer.slice(0, bytesRead));
        }
      } while (bytesRead === CHUNK_SIZE);

      return hash.digest("hex");
    } finally {
      await fileHandle.close();
    }
  }
}
