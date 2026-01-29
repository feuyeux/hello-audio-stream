/**
 * Memory-mapped cache for efficient file I/O.
 * Provides write, read, resize, and finalize operations.
 * Matches Python MmapCache functionality.
 */

import fs from "fs";
import path from "path";

const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
const MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024; // 2GB

/**
 * Memory-mapped cache implementation.
 */
export class MemoryMappedCache {
  /**
   * Create a new MemoryMappedCache.
   *
   * @param {string} filePath - Path to the cache file
   */
  constructor(filePath) {
    this.path = filePath;
    this.fileHandle = null;
    this.size = 0;
    this.isOpen = false;
    this.buffer = null;
  }

  /**
   * Create a new memory-mapped file.
   *
   * @param {string} filePath - Path to the file
   * @param {number} initialSize - Initial size in bytes
   * @returns {boolean} True if successful
   */
  create(filePath, initialSize = 0) {
    try {
      // Remove existing file
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      // Create and open file
      this.fileHandle = fs.openSync(filePath, "w+");

      if (initialSize > 0) {
        // Write zeros to allocate space
        const buffer = Buffer.alloc(initialSize);
        fs.writeSync(this.fileHandle, buffer, 0, initialSize, 0);
        this.size = initialSize;
      } else {
        this.size = 0;
      }

      this.isOpen = true;
      return true;
    } catch (error) {
      console.error(`Error creating file ${filePath}:`, error);
      return false;
    }
  }

  /**
   * Open an existing memory-mapped file.
   *
   * @param {string} filePath - Path to the file
   * @returns {boolean} True if successful
   */
  open(filePath) {
    try {
      if (!fs.existsSync(filePath)) {
        console.error(`File does not exist: ${filePath}`);
        return false;
      }

      this.fileHandle = fs.openSync(filePath, "r+");
      this.size = fs.statSync(filePath).size;
      this.isOpen = true;
      return true;
    } catch (error) {
      console.error(`Error opening file ${filePath}:`, error);
      return false;
    }
  }

  /**
   * Close the memory-mapped file.
   */
  close() {
    if (this.isOpen && this.fileHandle !== null) {
      fs.closeSync(this.fileHandle);
      this.fileHandle = null;
      this.isOpen = false;
      this.buffer = null;
    }
  }

  /**
   * Write data to the file.
   *
   * @param {number} offset - Offset to write to
   * @param {Buffer} data - Data to write
   * @returns {number} Number of bytes written
   */
  write(offset, data) {
    try {
      if (!this.isOpen || this.fileHandle === null) {
        const initialSize = offset + data.length;
        if (!this.create(this.path, initialSize)) {
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

      const written = fs.writeSync(
        this.fileHandle,
        data,
        0,
        data.length,
        offset,
      );
      return written;
    } catch (error) {
      console.error(`Error writing to file ${this.path}:`, error);
      return 0;
    }
  }

  /**
   * Read data from the file.
   *
   * @param {number} offset - Offset to read from
   * @param {number} length - Number of bytes to read
   * @returns {Buffer} Data read, or empty buffer on error
   */
  read(offset, length) {
    try {
      if (!this.isOpen || this.fileHandle === null) {
        if (!this.open(this.path)) {
          console.error(`Failed to open file for reading: ${this.path}`);
          return Buffer.alloc(0);
        }
      }

      if (offset >= this.size) {
        return Buffer.alloc(0);
      }

      const actualLength = Math.min(length, this.size - offset);
      const buffer = Buffer.alloc(actualLength);
      const bytesRead = fs.readSync(
        this.fileHandle,
        buffer,
        0,
        actualLength,
        offset,
      );

      if (bytesRead < actualLength) {
        return buffer.subarray(0, bytesRead);
      }

      return buffer;
    } catch (error) {
      console.error(`Error reading from file ${this.path}:`, error);
      return Buffer.alloc(0);
    }
  }

  /**
   * Get the size of the file.
   *
   * @returns {number} File size in bytes
   */
  getSize() {
    return this.size;
  }

  /**
   * Get the path of the file.
   *
   * @returns {string} File path
   */
  getPath() {
    return this.path;
  }

  /**
   * Check if the file is open.
   *
   * @returns {boolean} True if open
   */
  getIsOpen() {
    return this.isOpen;
  }

  /**
   * Resize the file to a new size.
   *
   * @param {number} newSize - New size in bytes
   * @returns {boolean} True if successful
   */
  resize(newSize) {
    try {
      if (!this.isOpen) {
        console.error(`File not open for resize: ${this.path}`);
        return false;
      }

      if (newSize === this.size) {
        return true;
      }

      if (newSize < this.size) {
        // Truncate
        fs.ftruncateSync(this.fileHandle, newSize);
      } else {
        // Expand - write zeros at the end
        const buffer = Buffer.alloc(newSize - this.size);
        fs.writeSync(this.fileHandle, buffer, 0, buffer.length, this.size);
      }

      this.size = newSize;
      return true;
    } catch (error) {
      console.error(`Error resizing file ${this.path}:`, error);
      return false;
    }
  }

  /**
   * Finalize the file to its final size.
   *
   * @param {number} finalSize - Final size in bytes
   * @returns {boolean} True if successful
   */
  finalize(finalSize) {
    try {
      if (!this.isOpen) {
        console.warn(`File not open for finalization: ${this.path}`);
        return false;
      }

      if (!this.resize(finalSize)) {
        console.error(
          `Failed to resize file during finalization: ${this.path}`,
        );
        return false;
      }

      // Sync to disk
      fs.fsyncSync(this.fileHandle);

      return true;
    } catch (error) {
      console.error(`Error finalizing file ${this.path}:`, error);
      return false;
    }
  }
}
