/**
 * File manager for file I/O operations.
 * Handles reading and writing file chunks with SHA-256 checksum calculation.
 * Matches Java FileManager functionality.
 */

import * as fs from "fs/promises";
import * as crypto from "crypto";

export class FileManager {
  private static readonly CHUNK_SIZE = 65536; // 64KB

  async getFileSize(filePath: string): Promise<number> {
    const stats = await fs.stat(filePath);
    return stats.size;
  }

  async readChunk(
    filePath: string,
    offset: number,
    length: number,
  ): Promise<Buffer> {
    const fileHandle = await fs.open(filePath, "r");
    try {
      const buffer = Buffer.alloc(length);
      const { bytesRead } = await fileHandle.read(buffer, 0, length, offset);
      return buffer.slice(0, bytesRead);
    } finally {
      await fileHandle.close();
    }
  }

  async writeChunk(
    filePath: string,
    data: Buffer,
    append: boolean,
  ): Promise<void> {
    const flag = append ? "a" : "w";
    await fs.writeFile(filePath, data, { flag });
  }

  async calculateChecksum(filePath: string): Promise<string> {
    const fileHandle = await fs.open(filePath, "r");
    const hash = crypto.createHash("sha256");

    try {
      const buffer = Buffer.alloc(FileManager.CHUNK_SIZE);
      let bytesRead: number;

      do {
        const result = await fileHandle.read(
          buffer,
          0,
          FileManager.CHUNK_SIZE,
          null,
        );
        bytesRead = result.bytesRead;
        if (bytesRead > 0) {
          hash.update(buffer.slice(0, bytesRead));
        }
      } while (bytesRead === FileManager.CHUNK_SIZE);

      return hash.digest("hex");
    } finally {
      await fileHandle.close();
    }
  }

  getChunkSize(): number {
    return FileManager.CHUNK_SIZE;
  }
}
