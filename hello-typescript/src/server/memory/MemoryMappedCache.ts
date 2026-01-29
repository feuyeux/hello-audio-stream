/**
 * Memory-mapped cache for audio streaming.
 * Provides file-based caching with memory mapping.
 * Matches C++ MemoryMappedCache and Java MemoryMappedCache.
 * Follows the unified mmap implementation specification v2.0.0.
 */

import * as fs from "fs";
import * as logger from "../../logger";

// Configuration constants
export const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
export const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8GB
export const SEGMENT_SIZE = 1 * 1024 * 1024 * 1024; // 1GB per segment
export const BATCH_OPERATION_LIMIT = 1000; // Max batch operations

export class MemoryMappedCache {
  private path: string;
  private fd: number | null;
  private size: number;
  private isOpenFlag: boolean;

  constructor(filePath: string) {
    this.path = filePath;
    this.fd = null;
    this.size = 0;
    this.isOpenFlag = false;
  }

  create(initialSize: number = 0): boolean {
    try {
      // Remove existing file if it exists
      if (fs.existsSync(this.path)) {
        fs.unlinkSync(this.path);
      }

      // Create new file
      this.fd = fs.openSync(this.path, "w+");

      if (initialSize > 0) {
        fs.ftruncateSync(this.fd, initialSize);
        this.size = initialSize;
      } else {
        this.size = 0;
      }

      this.isOpenFlag = true;
      return true;
    } catch (error) {
      logger.error(`Error creating file ${this.path}: ${(error as Error).message}`);
      return false;
    }
  }

  open(): boolean {
    try {
      if (!fs.existsSync(this.path)) {
        logger.error(`File does not exist: ${this.path}`);
        return false;
      }

      this.fd = fs.openSync(this.path, "r+");
      const stats = fs.fstatSync(this.fd);
      this.size = stats.size;
      this.isOpenFlag = true;
      return true;
    } catch (error) {
      logger.error(`Error opening file ${this.path}: ${(error as Error).message}`);
      return false;
    }
  }

  close(): void {
    if (this.isOpenFlag && this.fd !== null) {
      fs.closeSync(this.fd);
      this.fd = null;
      this.isOpenFlag = false;
    }
  }

  write(offset: number, data: Buffer): number {
    try {
      if (!this.isOpenFlag) {
        const initialSize = offset + data.length;
        if (!this.create(initialSize)) {
          return 0;
        }
      }

      const requiredSize = offset + data.length;
      if (requiredSize > this.size) {
        if (!this.resize(requiredSize)) {
          logger.error("Failed to resize file for write operation");
          return 0;
        }
      }

      if (this.fd === null) {
        return 0;
      }

      const written = fs.writeSync(this.fd, data, 0, data.length, offset);
      return written;
    } catch (error) {
      logger.error(`Error writing to file ${this.path}: ${(error as Error).message}`);
      return 0;
    }
  }

  read(offset: number, length: number): Buffer {
    try {
      if (!this.isOpenFlag) {
        if (!this.open()) {
          logger.error(`Failed to open file for reading: ${this.path}`);
          return Buffer.alloc(0);
        }
      }

      if (this.fd === null) {
        return Buffer.alloc(0);
      }

      if (offset >= this.size) {
        return Buffer.alloc(0);
      }

      const actualLength = Math.min(length, this.size - offset);
      const buffer = Buffer.alloc(actualLength);
      const bytesRead = fs.readSync(this.fd, buffer, 0, actualLength, offset);

      return buffer.slice(0, bytesRead);
    } catch (error) {
      logger.error(`Error reading from file ${this.path}: ${(error as Error).message}`);
      return Buffer.alloc(0);
    }
  }

  resize(newSize: number): boolean {
    try {
      if (!this.isOpenFlag || this.fd === null) {
        logger.error(`File not open for resize: ${this.path}`);
        return false;
      }

      if (newSize === this.size) {
        return true;
      }

      fs.ftruncateSync(this.fd, newSize);
      this.size = newSize;
      return true;
    } catch (error) {
      logger.error(`Error resizing file ${this.path}: ${(error as Error).message}`);
      return false;
    }
  }

  flush(): boolean {
    try {
      if (!this.isOpenFlag || this.fd === null) {
        logger.warn(`File not open for flush: ${this.path}`);
        return false;
      }

      fs.fsyncSync(this.fd);
      logger.debug(`Flushed file: ${this.path}`);
      return true;
    } catch (error) {
      logger.error(`Error flushing file ${this.path}: ${(error as Error).message}`);
      return false;
    }
  }

  finalize(finalSize: number): boolean {
    try {
      if (!this.isOpenFlag) {
        logger.warn(`File not open for finalization: ${this.path}`);
        return false;
      }

      if (!this.resize(finalSize)) {
        logger.error(
          `Failed to resize file during finalization: ${this.path}`,
        );
        return false;
      }

      if (this.fd !== null) {
        fs.fsyncSync(this.fd);
      }

      return true;
    } catch (error) {
      logger.error(`Error finalizing file ${this.path}: ${(error as Error).message}`);
      return false;
    }
  }

  getSize(): number {
    return this.size;
  }

  getPath(): string {
    return this.path;
  }

  isOpen(): boolean {
    return this.isOpenFlag;
  }
}
