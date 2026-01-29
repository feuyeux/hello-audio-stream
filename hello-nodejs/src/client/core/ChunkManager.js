/**
 * Chunk manager for handling file chunking operations
 */

export class ChunkManager {
  constructor(chunkSize = 8192) {
    this.chunkSize = chunkSize;
  }

  /**
   * Calculate the number of chunks for a given file size.
   *
   * @param {number} fileSize - Total file size in bytes
   * @returns {number} Number of chunks
   */
  calculateChunkCount(fileSize) {
    return Math.ceil(fileSize / this.chunkSize);
  }

  /**
   * Get chunk size for a specific chunk index.
   *
   * @param {number} chunkIndex - Index of the chunk
   * @param {number} fileSize - Total file size
   * @returns {number} Size of the chunk
   */
  getChunkSize(chunkIndex, fileSize) {
    const offset = chunkIndex * this.chunkSize;
    return Math.min(this.chunkSize, fileSize - offset);
  }

  /**
   * Get offset for a specific chunk index.
   *
   * @param {number} chunkIndex - Index of the chunk
   * @returns {number} Offset in bytes
   */
  getChunkOffset(chunkIndex) {
    return chunkIndex * this.chunkSize;
  }
}
