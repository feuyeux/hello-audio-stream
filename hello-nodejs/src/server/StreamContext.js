/**
 * Stream context for managing active audio streams.
 * Contains stream metadata and cache file handle.
 * Matches Python StreamContext and Java StreamContext functionality.
 */

const fs = require("fs");
const path = require("path");

/**
 * Stream status enumeration
 */
const StreamStatus = {
  UPLOADING: "UPLOADING",
  READY: "READY",
  ERROR: "ERROR",
};

/**
 * Stream context containing metadata and state for a single stream.
 */
class StreamContext {
  /**
   * Create a new StreamContext.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @param {string} cachePath - Path to the cache file
   */
  constructor(streamId, cachePath = "") {
    this.streamId = streamId;
    this.cachePath = cachePath;
    this.mmapFile = null;
    this.currentOffset = 0;
    this.totalSize = 0;
    this.createdAt = new Date();
    this.lastAccessedAt = new Date();
    this.status = StreamStatus.UPLOADING;
    this.fileHandle = null;
    this.buffer = null;
  }

  /**
   * Update last accessed timestamp
   */
  updateAccessTime() {
    this.lastAccessedAt = new Date();
  }

  /**
   * Get stream status
   *
   * @returns {string} Current status
   */
  getStatus() {
    return this.status;
  }

  /**
   * Set stream status
   *
   * @param {string} status - New status
   */
  setStatus(status) {
    this.status = status;
  }

  /**
   * Get stream ID
   *
   * @returns {string} Stream ID
   */
  getStreamId() {
    return this.streamId;
  }

  /**
   * Get cache path
   *
   * @returns {string} Cache file path
   */
  getCachePath() {
    return this.cachePath;
  }

  /**
   * Get current offset
   *
   * @returns {number} Current offset in bytes
   */
  getCurrentOffset() {
    return this.currentOffset;
  }

  /**
   * Set current offset
   *
   * @param {number} offset - New offset in bytes
   */
  setCurrentOffset(offset) {
    this.currentOffset = offset;
  }

  /**
   * Get total size
   *
   * @returns {number} Total size in bytes
   */
  getTotalSize() {
    return this.totalSize;
  }

  /**
   * Set total size
   *
   * @param {number} size - Total size in bytes
   */
  setTotalSize(size) {
    this.totalSize = size;
  }

  /**
   * Get created at timestamp
   *
   * @returns {Date} Creation timestamp
   */
  getCreatedAt() {
    return this.createdAt;
  }

  /**
   * Get last accessed at timestamp
   *
   * @returns {Date} Last access timestamp
   */
  getLastAccessedAt() {
    return this.lastAccessedAt;
  }

  /**
   * Get memory-mapped file handle
   *
   * @returns {object} File handle
   */
  getMmapFile() {
    return this.mmapFile;
  }

  /**
   * Set memory-mapped file handle
   *
   * @param {object} file - File handle
   */
  setMmapFile(file) {
    this.mmapFile = file;
  }
}

module.exports = { StreamContext, StreamStatus };
