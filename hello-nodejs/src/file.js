/**
 * File I/O operations with SHA-256 checksum calculation
 */

import fs from "fs/promises";
import crypto from "crypto";

export const CHUNK_SIZE = 65536; // 64KB

export async function getFileSize(filePath) {
  const stats = await fs.stat(filePath);
  return stats.size;
}

export async function readChunk(filePath, offset, length) {
  const fileHandle = await fs.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(length);
    const { bytesRead } = await fileHandle.read(buffer, 0, length, offset);
    return buffer.slice(0, bytesRead);
  } finally {
    await fileHandle.close();
  }
}

export async function writeChunk(filePath, data, append) {
  const flag = append ? "a" : "w";
  await fs.writeFile(filePath, data, { flag });
}

export async function calculateChecksum(filePath) {
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
