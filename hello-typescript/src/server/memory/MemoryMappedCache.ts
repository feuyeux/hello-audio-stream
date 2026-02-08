/**
 * Memory-mapped cache for audio streaming.
 * Provides file-based caching with memory mapping.
 * Matches C++ MemoryMappedCache and Java MemoryMappedCache.
 * Follows the unified mmap implementation specification v2.0.0.
 */

import * as fs from "fs";
import mmap from "mmap-io";

// Configuration constants - follows unified mmap implementation specification v2.0.0
const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8GB
const SEGMENT_SIZE = 1 * 1024 * 1024 * 1024; // 1GB per segment
const BATCH_OPERATION_LIMIT = 1000; // Max batch operations

export class MemoryMappedCache {
  private path: string;
  private fd: number | null;
  private size: number;
  private isOpenFlag: boolean;
  private buffer: Buffer | null;

  constructor(path: string) {
    this.path = path;
    this.fd = null;
    this.size = 0;
    this.isOpenFlag = false;
    this.buffer = null;
  }

  create(initialSize: number = 0): boolean {
    try {
      if (fs.existsSync(this.path)) {
        fs.unlinkSync(this.path);
      }

      this.fd = fs.openSync(this.path, "w+");

      if (initialSize > 0) {
        fs.ftruncateSync(this.fd, initialSize);
        this.size = initialSize;
        this.mapFile();
      } else {
        this.size = 0;
      }

      this.isOpenFlag = true;
      console.log(`Created mmap file: ${this.path} with size: ${initialSize}`);
      return true;
    } catch (err: any) {
      console.error(`Error creating file ${this.path}: ${err.message}`);
      return false;
    }
  }

  open(): boolean {
    try {
      if (!fs.existsSync(this.path)) {
        console.error(`File does not exist: ${this.path}`);
        return false;
      }

      this.fd = fs.openSync(this.path, "r+");
      const stats = fs.fstatSync(this.fd);
      this.size = stats.size;

      if (this.size > 0) {
        this.mapFile();
      }

      this.isOpenFlag = true;
      console.log(`Opened mmap file: ${this.path} with size: ${this.size}`);
      return true;
    } catch (err: any) {
      console.error(`Error opening file ${this.path}: ${err.message}`);
      return false;
    }
  }

  close(): void {
    if (this.isOpenFlag && this.fd !== null) {
      try {
        if (this.buffer) {
          // Unmap if mapped
          // mmap-io cleanup relying on GC or closing fd
        }
        fs.closeSync(this.fd);
        this.fd = null;
        this.isOpenFlag = false;
        this.buffer = null;
      } catch (err: any) {
        console.error(`Error closing file: ${err.message}`);
      }
    }
  }

  write(offset: number, data: Buffer): number {
    if (!this.isOpenFlag || this.fd === null) {
      const initialSize = offset + data.length;
      if (!this.create(initialSize)) {
        return 0;
      }
    }

    const requiredSize = offset + data.length;
    if (requiredSize > this.size) {
      if (!this.resize(requiredSize)) {
        console.error("Failed to resize file for write operation");
        return 0;
      }
    }

    try {
      // Write to memory buffer
      if (this.buffer) {
        data.copy(this.buffer, offset);
        return data.length;
      } else {
        // Fallback if buffer not mapped (should not happen if logic correct)
        fs.writeSync(this.fd!, data, 0, data.length, offset);
        return data.length;
      }
    } catch (err: any) {
      console.error(`Error writing to file ${this.path}: ${err.message}`);
      return 0;
    }
  }

  read(offset: number, length: number): Buffer {
    if (!this.isOpenFlag || this.fd === null) {
      if (!this.open()) {
        console.error(`Failed to open file for reading: ${this.path}`);
        return Buffer.alloc(0);
      }
    }

    if (offset >= this.size) {
      return Buffer.alloc(0);
    }

    const actualLength = Math.min(length, this.size - offset);

    try {
      if (this.buffer) {
        const result = Buffer.alloc(actualLength);
        this.buffer.copy(result, 0, offset, offset + actualLength);
        console.log(`Read ${actualLength} bytes from ${this.path} at offset ${offset}`);
        return result;
      } else {
        const buffer = Buffer.alloc(actualLength);
        const bytesRead = fs.readSync(this.fd!, buffer, 0, actualLength, offset);
        console.log(`Read ${bytesRead} bytes from ${this.path} at offset ${offset}`);
        return buffer;
      }
    } catch (err: any) {
      console.error(`Error reading from file ${this.path}: ${err.message}`);
      return Buffer.alloc(0);
    }
  }

  resize(newSize: number): boolean {
    if (!this.isOpenFlag) {
      console.error(`File not open for resize: ${this.path}`);
      return false;
    }

    if (newSize === this.size) {
      return true;
    }

    try {
      fs.ftruncateSync(this.fd!, newSize);
      this.size = newSize;

      // Re-map with new size
      this.mapFile();

      console.log(`Resized file ${this.path} to ${newSize} bytes`);
      return true;
    } catch (err: any) {
      console.error(`Error resizing file ${this.path}: ${err.message}`);
      return false;
    }
  }

  flush(): boolean {
    if (!this.isOpenFlag || this.fd === null) {
      console.warn(`File not open for flush: ${this.path}`);
      return false;
    }

    try {
      if (this.buffer) {
        // mmap-io sync: mmap.sync(buffer, offset, length, blocking_sync, invalidate_pages)
        mmap.sync(this.buffer, 0, this.size, true);
      } else {
        fs.fsyncSync(this.fd);
      }

      console.log(`Flushed file: ${this.path}`);
      return true;
    } catch (err: any) {
      console.error(`Error flushing file: ${err.message}`);
      return false;
    }
  }

  finalize(finalSize: number): boolean {
    if (!this.isOpenFlag) {
      console.warn(`File not open for finalization: ${this.path}`);
      return false;
    }

    if (!this.resize(finalSize)) {
      console.error(`Failed to resize file during finalization: ${this.path}`);
      return false;
    }

    // Sync to disk
    this.flush();

    console.log(`Finalized file: ${this.path} with size: ${finalSize}`);
    return true;
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

  private mapFile(): void {
    if (this.fd !== null && this.size > 0) {
      // mmap.map(size, protection, privacy, fd, offset, advise)
      // PROT_READ | PROT_WRITE, MAP_SHARED
      this.buffer = mmap.map(
        this.size,
        (mmap.PROT_READ | mmap.PROT_WRITE) as any,
        mmap.MAP_SHARED,
        this.fd,
        0
      );
    }
  }
}
