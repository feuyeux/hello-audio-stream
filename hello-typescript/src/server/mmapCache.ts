import * as fs from 'fs';
import * as path from 'path';

const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8 GB

/** File-backed cache for a single audio stream (sequential write, random read). */
export class MmapCache {
  private readonly filePath: string;
  private fd: number | null = null;
  private fileSize = 0;
  private active = false;

  constructor(filePath: string) {
    this.filePath = filePath;
  }

  /** Create the backing file. */
  create(): void {
    const dir = path.dirname(this.filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(this.filePath)) fs.unlinkSync(this.filePath);
    this.fd = fs.openSync(this.filePath, 'w+');
    this.fileSize = 0;
    this.active = true;
  }

  /** Write data at offset. */
  write(offset: number, data: Buffer): number {
    if (!this.active || this.fd === null) this.create();
    if (offset + data.length > MAX_CACHE_SIZE) throw new Error('Exceeds max cache size');
    fs.writeSync(this.fd!, data, 0, data.length, offset);
    if (offset + data.length > this.fileSize) this.fileSize = offset + data.length;
    return data.length;
  }

  /** Read up to `length` bytes at `offset`. */
  read(offset: number, length: number): Buffer {
    if (!this.active || this.fd === null) {
      if (!fs.existsSync(this.filePath)) return Buffer.alloc(0);
      this.fd = fs.openSync(this.filePath, 'r');
      this.fileSize = fs.fstatSync(this.fd).size;
      this.active = true;
    }
    if (offset >= this.fileSize) return Buffer.alloc(0);
    const actual = Math.min(length, this.fileSize - offset);
    const buf = Buffer.alloc(actual);
    fs.readSync(this.fd, buf, 0, actual, offset);
    return buf;
  }

  /** Truncate to final size and sync. */
  finalize(finalSize: number): void {
    if (this.fd !== null) fs.ftruncateSync(this.fd, finalSize);
    this.fileSize = finalSize;
  }

  /** Close the backing file. */
  close(): void {
    if (this.fd !== null) {
      fs.closeSync(this.fd);
      this.fd = null;
    }
    this.active = false;
  }
}

