/**
 * Memory pool manager for reusable buffers.
 * Singleton pattern implementation for shared buffer pool.
 * Matches C++ MemoryPoolManager and Java MemoryPoolManager.
 */

export class MemoryPoolManager {
  private static instance: MemoryPoolManager | null = null;
  private bufferSize: number;
  private poolSize: number;
  private availableBuffers: Buffer[];
  private totalBuffers: number;

  private constructor(bufferSize: number = 65536, poolSize: number = 100) {
    this.bufferSize = bufferSize;
    this.poolSize = poolSize;
    this.availableBuffers = [];
    this.totalBuffers = 0;

    // Pre-allocate buffers
    for (let i = 0; i < poolSize; i++) {
      const buffer = Buffer.alloc(bufferSize);
      this.availableBuffers.push(buffer);
      this.totalBuffers++;
    }

    console.log(
      `MemoryPoolManager initialized with ${poolSize} buffers of ${bufferSize} bytes each`,
    );
  }

  static getInstance(
    bufferSize: number = 65536,
    poolSize: number = 100,
  ): MemoryPoolManager {
    if (!MemoryPoolManager.instance) {
      MemoryPoolManager.instance = new MemoryPoolManager(bufferSize, poolSize);
    }
    return MemoryPoolManager.instance;
  }

  acquireBuffer(): Buffer {
    if (this.availableBuffers.length > 0) {
      const buffer = this.availableBuffers.pop()!;
      return buffer;
    } else {
      // Pool exhausted, allocate new buffer
      const buffer = Buffer.alloc(this.bufferSize);
      this.totalBuffers++;
      return buffer;
    }
  }

  releaseBuffer(buffer: Buffer): void {
    if (buffer.length !== this.bufferSize) {
      console.warn(
        `Buffer size mismatch: expected ${this.bufferSize}, got ${buffer.length}`,
      );
      return;
    }

    // Clear buffer before returning to pool
    buffer.fill(0);
    this.availableBuffers.push(buffer);
  }

  getAvailableBuffers(): number {
    return this.availableBuffers.length;
  }

  getTotalBuffers(): number {
    return this.totalBuffers;
  }
}
