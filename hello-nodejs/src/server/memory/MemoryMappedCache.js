/**
 * Memory-mapped cache for efficient file I/O.
 * Provides write, read, resize, and finalize operations.
 * Matches Python MmapCache functionality.
 */

import fs from "fs";
import path from "path";
import * as logger from "../../logger.js";

// Configuration constants - follows unified mmap specification v2.0.0
const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024; // 64MB
const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8GB
const SEGMENT_SIZE = 1 * 1024 * 1024 * 1024; // 1GB per segment
const BATCH_OPERATION_LIMIT = 1000; // Max batch operations

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
    this._isOpen = false;
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

      this._isOpen = true;
      return true;
    } catch (error) {
      logger.error(`Error creating file ${filePath}: ${error.message}`);
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
        logger.error(`File does not exist: ${filePath}`);
        return false;
      }

      this.fileHandle = fs.openSync(filePath, "r+");
      this.size = fs.statSync(filePath).size;
      this._isOpen = true;
      return true;
    } catch (error) {
      logger.error(`Error opening file ${filePath}: ${error.message}`);
      return false;
    }
  }

  /**
   * Close the memory-mapped file.
   */
  close() {
    if (this._isOpen && this.fileHandle !== null) {
      fs.closeSync(this.fileHandle);
      this.fileHandle = null;
      this._isOpen = false;
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
      if (!this._isOpen || this.fileHandle === null) {
        const initialSize = offset + data.length;
        if (!this.create(this.path, initialSize)) {
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

      const written = fs.writeSync(
        this.fileHandle,
        data,
        0,
        data.length,
        offset,
      );
      return written;
    } catch (error) {
      logger.error(`Error writing to file ${this.path}: ${error.message}`);
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
      if (!this._isOpen || this.fileHandle === null) {
        if (!this.open(this.path)) {
          logger.error(`Failed to open file for reading: ${this.path}`);
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
      logger.error(`Error reading from file ${this.path}: ${error.message}`);
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
  isOpen() {
    return this._isOpen;
  }

  /**
   * Resize the file to a new size.
   *
   * @param {number} newSize - New size in bytes
   * @returns {boolean} True if successful
   */
  resize(newSize) {
    try {
      if (!this._isOpen) {
        logger.error(`File not open for resize: ${this.path}`);
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
      logger.error(`Error resizing file ${this.path}: ${error.message}`);
      return false;
    }
  }

  /**
   * Flush all data to disk.
   *
   * @returns {boolean} True if successful
   */
  flush() {
    try {
      if (!this._isOpen || this.fileHandle === null) {
        logger.warn(`File not open for flush: ${this.path}`);
        return false;
      }

      fs.fsyncSync(this.fileHandle);
      logger.debug(`Flushed file: ${this.path}`);
      return true;
    } catch (error) {
      logger.error(`Error flushing file ${this.path}: ${error.message}`);
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
      if (!this._isOpen) {
        logger.warn(`File not open for finalization: ${this.path}`);
        return false;
      }

      if (!this.resize(finalSize)) {
        logger.error(
          `Failed to resize file during finalization: ${this.path}`,
        );
        return false;
      }

      // Sync to disk
      fs.fsyncSync(this.fileHandle);

      return true;
    } catch (error) {
      logger.error(`Error finalizing file ${this.path}: ${error.message}`);
      return false;
    }
  }
}
