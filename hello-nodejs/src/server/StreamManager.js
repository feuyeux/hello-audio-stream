/**
 * Stream manager for managing active audio streams.
 * Thread-safe registry of stream contexts.
 * Matches Python StreamManager and Java StreamManager functionality.
 */

const fs = require("fs");
const path = require("path");

const { StreamContext, StreamStatus } = require("./StreamContext");
const MemoryMappedCache = require("./MemoryMappedCache");

/**
 * Stream manager for managing multiple concurrent streams.
 */
class StreamManager {
  /**
   * Get the singleton instance of StreamManager.
   *
   * @param {string} cacheDirectory - Directory for cache files (default 'cache')
   * @returns {StreamManager} The singleton instance
   */
  static getInstance(cacheDirectory = "cache") {
    if (!StreamManager.instance) {
      StreamManager.instance = new StreamManager(cacheDirectory);
    }
    return StreamManager.instance;
  }

  /**
   * Private constructor for singleton pattern.
   *
   * @param {string} cacheDirectory - Directory for cache files
   */
  constructor(cacheDirectory) {
    if (StreamManager.instance) {
      throw new Error("Use getInstance() to get the singleton instance");
    }

    this.cacheDirectory = cacheDirectory;
    this.streams = new Map();
    this.mutex = {
      lock() {
        return this._lock || (this._lock = Promise.resolve());
      },
      async run(callback) {
        const release = await this.lock();
        try {
          return await callback();
        } finally {
          this._lock = Promise.resolve();
        }
      },
    };

    // Create cache directory if it doesn't exist
    if (!fs.existsSync(cacheDirectory)) {
      fs.mkdirSync(cacheDirectory, { recursive: true });
    }

    console.log(
      `StreamManager initialized with cache directory: ${cacheDirectory}`,
    );
  }

  /**
   * Create a new stream.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @returns {Promise<boolean>} True if successful, False if stream already exists
   */
  async createStream(streamId) {
    return this.mutex.run(() => {
      // Check if stream already exists
      if (this.streams.has(streamId)) {
        console.warn(`Stream already exists: ${streamId}`);
        return false;
      }

      try {
        // Create new stream context
        const cachePath = this._getCachePath(streamId);
        const context = new StreamContext(streamId, cachePath);
        context.setStatus(StreamStatus.UPLOADING);
        context.updateAccessTime();

        // Create memory-mapped cache file
        const mmapFile = new MemoryMappedCache(cachePath);
        context.setMmapFile(mmapFile);

        // Add to registry
        this.streams.set(streamId, context);

        console.log(`Created stream: ${streamId} at path: ${cachePath}`);
        return true;
      } catch (error) {
        console.error(`Failed to create stream ${streamId}:`, error);
        return false;
      }
    });
  }

  /**
   * Get a stream context.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @returns {Promise<StreamContext|null>} Stream context or null if not found
   */
  async getStream(streamId) {
    return this.mutex.run(() => {
      const context = this.streams.get(streamId);
      if (context) {
        context.updateAccessTime();
      }
      return context || null;
    });
  }

  /**
   * Delete a stream.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @returns {Promise<boolean>} True if successful
   */
  async deleteStream(streamId) {
    return this.mutex.run(() => {
      const context = this.streams.get(streamId);
      if (!context) {
        console.warn(`Stream not found for deletion: ${streamId}`);
        return false;
      }

      try {
        // Close memory-mapped file
        const mmapFile = context.getMmapFile();
        if (mmapFile) {
          mmapFile.close();
        }

        // Remove cache file
        if (fs.existsSync(context.getCachePath())) {
          fs.unlinkSync(context.getCachePath());
        }

        // Remove from registry
        this.streams.delete(streamId);

        console.log(`Deleted stream: ${streamId}`);
        return true;
      } catch (error) {
        console.error(`Failed to delete stream ${streamId}:`, error);
        return false;
      }
    });
  }

  /**
   * List all active streams.
   *
   * @returns {Promise<string[]>} List of stream IDs
   */
  async listActiveStreams() {
    return this.mutex.run(() => Array.from(this.streams.keys()));
  }

  /**
   * Write a chunk of data to a stream.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @param {Buffer} data - Data to write
   * @returns {Promise<boolean>} True if successful
   */
  async writeChunk(streamId, data) {
    const stream = await this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for write: ${streamId}`);
      return false;
    }

    if (stream.getStatus() !== StreamStatus.UPLOADING) {
      console.error(`Stream ${streamId} is not in uploading state`);
      return false;
    }

    try {
      // Write data to memory-mapped file
      const mmapFile = stream.getMmapFile();
      const written = mmapFile.write(stream.getCurrentOffset(), data);

      if (written > 0) {
        stream.setCurrentOffset(stream.getCurrentOffset() + written);
        stream.setTotalSize(stream.getTotalSize() + written);
        stream.updateAccessTime();

        console.debug(
          `Wrote ${written} bytes to stream ${streamId} at offset ${stream.getCurrentOffset() - written}`,
        );
        return true;
      } else {
        console.error(`Failed to write data to stream ${streamId}`);
        return false;
      }
    } catch (error) {
      console.error(`Error writing to stream ${streamId}:`, error);
      return false;
    }
  }

  /**
   * Read a chunk of data from a stream.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @param {number} offset - Starting position
   * @param {number} length - Number of bytes to read
   * @returns {Promise<Buffer>} Data read, or empty buffer if error
   */
  async readChunk(streamId, offset, length) {
    const stream = await this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for read: ${streamId}`);
      return Buffer.alloc(0);
    }

    try {
      // Read data from memory-mapped file
      const mmapFile = stream.getMmapFile();
      const data = mmapFile.read(offset, length);
      stream.updateAccessTime();

      console.debug(
        `Read ${data.length} bytes from stream ${streamId} at offset ${offset}`,
      );
      return data;
    } catch (error) {
      console.error(`Error reading from stream ${streamId}:`, error);
      return Buffer.alloc(0);
    }
  }

  /**
   * Finalize a stream (flush and mark as ready).
   *
   * @param {string} streamId - Unique identifier for the stream
   * @returns {Promise<boolean>} True if successful
   */
  async finalizeStream(streamId) {
    const stream = await this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for finalization: ${streamId}`);
      return false;
    }

    if (stream.getStatus() !== StreamStatus.UPLOADING) {
      console.warn(
        `Stream ${streamId} is not in uploading state for finalization`,
      );
      return false;
    }

    try {
      // Finalize memory-mapped file
      const mmapFile = stream.getMmapFile();
      if (mmapFile.finalize(stream.getTotalSize())) {
        stream.setStatus(StreamStatus.READY);
        stream.updateAccessTime();

        console.log(
          `Finalized stream: ${streamId} with ${stream.getTotalSize()} bytes`,
        );
        return true;
      } else {
        console.error(
          `Failed to finalize memory-mapped file for stream ${streamId}`,
        );
        return false;
      }
    } catch (error) {
      console.error(`Error finalizing stream ${streamId}:`, error);
      return false;
    }
  }

  /**
   * Clean up old streams (older than maxAgeHours).
   *
   * @param {number} maxAgeHours - Maximum age in hours (default 24)
   */
  async cleanupOldStreams(maxAgeHours = 24) {
    const now = new Date();
    const cutoff = maxAgeHours * 60 * 60 * 1000; // Convert to milliseconds

    const toRemove = [];
    for (const [streamId, context] of this.streams.entries()) {
      const age = now - context.getLastAccessedAt();
      if (age > cutoff) {
        toRemove.push(streamId);
      }
    }

    for (const streamId of toRemove) {
      console.log(`Cleaning up old stream: ${streamId}`);
      await this.deleteStream(streamId);
    }
  }

  /**
   * Get cache file path for a stream.
   *
   * @param {string} streamId - Unique identifier for the stream
   * @returns {string} Cache file path
   */
  _getCachePath(streamId) {
    return path.join(this.cacheDirectory, `${streamId}.cache`);
  }
}

module.exports = StreamManager;
