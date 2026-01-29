/**
 * Stream context for managing active audio streams.
 * Contains stream metadata and cache file handle.
 */

/**
 * Stream status enumeration
 */
export const StreamStatus = {
  UPLOADING: "UPLOADING",
  READY: "READY",
  ERROR: "ERROR",
};

/**
 * Stream context containing metadata and state for a single stream.
 */
export class StreamContext {
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

  updateAccessTime() {
    this.lastAccessedAt = new Date();
  }

  getStatus() {
    return this.status;
  }

  setStatus(status) {
    this.status = status;
  }

  getStreamId() {
    return this.streamId;
  }

  getCachePath() {
    return this.cachePath;
  }

  getCurrentOffset() {
    return this.currentOffset;
  }

  setCurrentOffset(offset) {
    this.currentOffset = offset;
  }

  getTotalSize() {
    return this.totalSize;
  }

  setTotalSize(size) {
    this.totalSize = size;
  }

  getCreatedAt() {
    return this.createdAt;
  }

  getLastAccessedAt() {
    return this.lastAccessedAt;
  }

  getMmapFile() {
    return this.mmapFile;
  }

  setMmapFile(file) {
    this.mmapFile = file;
  }
}
