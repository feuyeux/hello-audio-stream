/**
 * Memory-mapped cache for efficient file I/O.
 * Provides write, read, resize, and finalize operations.
 * Matches C++ MemoryMappedCache and Java MemoryMappedCache.
 * Follows the unified mmap implementation specification v2.0.0.
 */

import fs from "fs";
import mmap from "@fayzanx/mmap-io";
import * as logger from "../../logger.js";

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
   * @param {number} initialSize - Initial size in bytes
   * @returns {boolean} True if successful
   */
  create(initialSize = 0) {
    try {
      // Remove existing file
      if (fs.existsSync(this.path)) {
        fs.unlinkSync(this.path);
      }

      // Create and open file
      this.fileHandle = fs.openSync(this.path, "w+");

      if (initialSize > 0) {
        fs.ftruncateSync(this.fileHandle, initialSize);
        this.size = initialSize;
        this._mapFile();
      } else {
        this.size = 0;
      }

      this._isOpen = true;
      logger.info(`Created mmap file: ${this.path} with size: ${initialSize}`);
      return true;
    } catch (error) {
      logger.error(`Error creating file ${this.path}: ${error.message}`);
      return false;
    }
  }

  /**
   * Open an existing memory-mapped file.
   *
   * @returns {boolean} True if successful
   */
  open() {
    try {
      if (!fs.existsSync(this.path)) {
        logger.error(`File does not exist: ${this.path}`);
        return false;
      }

      this.fileHandle = fs.openSync(this.path, "r+");
      const stats = fs.fstatSync(this.fileHandle);
      this.size = stats.size;

      if (this.size > 0) {
        this._mapFile();
      }

      this._isOpen = true;
      logger.info(`Opened mmap file: ${this.path} with size: ${this.size}`);
      return true;
    } catch (error) {
      logger.error(`Error opening file ${this.path}: ${error.message}`);
      return false;
    }
  }

  /**
   * Close the memory-mapped file.
   */
  close() {
    if (this._isOpen && this.fileHandle !== null) {
      try {
        // mmap-io cleanup is handled by GC or explicit buffer release if available
        // but mostly we just close the FD
        fs.closeSync(this.fileHandle);
        this.fileHandle = null;
        this._isOpen = false;
        this.buffer = null;
      } catch (error) {
        logger.error(`Error closing file: ${error.message}`);
      }
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
    if (!this._isOpen || this.fileHandle === null) {
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

    try {
      if (this.buffer) {
        data.copy(this.buffer, offset);
        return data.length;
      } else {
        logger.error("Buffer not mapped; native mmap is required");
        return 0;
      }
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
    if (!this._isOpen || this.fileHandle === null) {
      if (!this.open()) {
        logger.error(`Failed to open file for reading: ${this.path}`);
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
        logger.debug(`Read ${actualLength} bytes from ${this.path} at offset ${offset}`);
        return result;
      } else {
        logger.error("Buffer not mapped; native mmap is required");
        return Buffer.alloc(0);
      }
    } catch (error) {
      logger.error(`Error reading from file ${this.path}: ${error.message}`);
      return Buffer.alloc(0);
    }
  }

  /**
   * Resize the file to a new size.
   *
   * @param {number} newSize - New size in bytes
   * @returns {boolean} True if successful
   */
  resize(newSize) {
    if (!this._isOpen) {
      logger.error(`File not open for resize: ${this.path}`);
      return false;
    }

    if (newSize === this.size) {
      return true;
    }

    try {
      fs.ftruncateSync(this.fileHandle, newSize);
      this.size = newSize;

      // Re-map with new size
      this._mapFile();

      logger.info(`Resized file ${this.path} to ${newSize} bytes`);
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
    if (!this._isOpen || this.fileHandle === null) {
      logger.warn(`File not open for flush: ${this.path}`);
      return false;
    }

    try {
      if (this.buffer) {
        // mmap.sync(buffer, offset, length, blocking_sync, invalidate_pages)
        mmap.sync(this.buffer, 0, this.size, true, false);
      } else {
        logger.error("Buffer not mapped; native mmap is required");
        return false;
      }
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
    this.flush();

    logger.info(`Finalized file: ${this.path} with size: ${finalSize}`);
    return true;
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
   * Map the file into memory.
   * @private
   */
  _mapFile() {
    if (this.fileHandle !== null && this.size > 0) {
      try {
        // mmap.map(size, protection, privacy, fd, offset, advise)
        // PROT_READ | PROT_WRITE, MAP_SHARED
        this.buffer = mmap.map(
          this.size,
          mmap.PROT_READ | mmap.PROT_WRITE,
          mmap.MAP_SHARED,
          this.fileHandle,
          0
        );
      } catch (error) {
        logger.error(`Failed to map file: ${error.message}`);
        this.buffer = null;
      }
    }
  }
}
