/**
 * Memory pool manager for efficient buffer reuse.
 * Pre-allocates buffers to minimize allocation overhead.
 * Implemented as a singleton to ensure a single shared pool across all streams.
 */

/**
 * Memory pool manager singleton.
 */
export class MemoryPoolManager {
  /**
   * Get the singleton instance of MemoryPoolManager.
   *
   * @param {number} bufferSize - Size of each buffer in bytes (default 65536)
   * @param {number} poolSize - Number of buffers to pre-allocate (default 100)
   * @returns {MemoryPoolManager} The singleton instance
   */
  static getInstance(bufferSize = 65536, poolSize = 100) {
    if (!MemoryPoolManager.instance) {
      MemoryPoolManager.instance = new MemoryPoolManager(bufferSize, poolSize);
    }
    return MemoryPoolManager.instance;
  }

  /**
   * Private constructor for singleton pattern.
   *
   * @param {number} bufferSize - Size of each buffer in bytes
   * @param {number} poolSize - Number of buffers to pre-allocate
   */
  constructor(bufferSize, poolSize) {
    if (MemoryPoolManager.instance) {
      throw new Error("Use getInstance() to get the singleton instance");
    }

    this.bufferSize = bufferSize;
    this.poolSize = poolSize;
    this.availableBuffers = [];
    this.totalBuffers = 0;
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

    // Pre-allocate buffers
    for (let i = 0; i < poolSize; i++) {
      const buffer = Buffer.alloc(bufferSize);
      this.availableBuffers.push(buffer);
      this.totalBuffers++;
    }

    console.log(
      `MemoryPoolManager initialized with ${poolSize} buffers of ${bufferSize} bytes`,
    );
  }

  /**
   * Acquire a buffer from the pool.
   *
   * @returns {Buffer} A buffer of size bufferSize
   */
  async acquireBuffer() {
    return this.mutex.run(() => {
      if (this.availableBuffers.length > 0) {
        const buffer = this.availableBuffers.shift();
        console.debug(
          `Acquired buffer from pool (${this.availableBuffers.length} remaining)`,
        );
        return buffer;
      } else {
        const buffer = Buffer.alloc(this.bufferSize);
        this.totalBuffers++;
        console.debug(
          `Pool exhausted, allocated new buffer (total: ${this.totalBuffers})`,
        );
        return buffer;
      }
    });
  }

  /**
   * Release a buffer back to the pool.
   *
   * @param {Buffer} buffer - The buffer to release
   */
  async releaseBuffer(buffer) {
    if (!buffer || buffer.length !== this.bufferSize) {
      console.warn(
        `Buffer size mismatch: expected ${this.bufferSize}, got ${buffer ? buffer.length : "null"}`,
      );
      return;
    }

    await this.mutex.run(() => {
      buffer.fill(0);
      if (this.availableBuffers.length < this.poolSize) {
        this.availableBuffers.push(buffer);
      }
    });

    console.debug(
      `Released buffer to pool (${this.availableBuffers.length} available)`,
    );
  }

  /**
   * Get the number of available buffers in the pool.
   *
   * @returns {number} Number of available buffers
   */
  async getAvailableBuffers() {
    return this.mutex.run(() => this.availableBuffers.length);
  }

  /**
   * Get the total number of buffers.
   *
   * @returns {number} Total number of buffers
   */
  getTotalBuffers() {
    return this.poolSize;
  }
}
