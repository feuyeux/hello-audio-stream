// File-backed cache for a single audio stream.
import * as fs from 'fs';
import * as path from 'path';

const MAX_CACHE_SIZE = 8 * 1024 * 1024 * 1024; // 8 GB

export class MmapCache {
  #filePath;
  #fd = null;
  #fileSize = 0;
  #active = false;

  constructor(filePath) {
    this.#filePath = filePath;
  }

  create() {
    const dir = path.dirname(this.#filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(this.#filePath)) fs.unlinkSync(this.#filePath);
    this.#fd = fs.openSync(this.#filePath, 'w+');
    this.#fileSize = 0;
    this.#active = true;
  }

  /** @param {number} offset @param {Buffer} data @returns {number} */
  write(offset, data) {
    if (!this.#active || this.#fd === null) this.create();
    if (offset + data.length > MAX_CACHE_SIZE) throw new Error('Exceeds max cache size');
    fs.writeSync(this.#fd, data, 0, data.length, offset);
    if (offset + data.length > this.#fileSize) this.#fileSize = offset + data.length;
    return data.length;
  }

  /** @param {number} offset @param {number} length @returns {Buffer} */
  read(offset, length) {
    if (!this.#active || this.#fd === null) {
      if (!fs.existsSync(this.#filePath)) return Buffer.alloc(0);
      this.#fd = fs.openSync(this.#filePath, 'r');
      this.#fileSize = fs.fstatSync(this.#fd).size;
      this.#active = true;
    }
    if (offset >= this.#fileSize) return Buffer.alloc(0);
    const actual = Math.min(length, this.#fileSize - offset);
    const buf = Buffer.alloc(actual);
    fs.readSync(this.#fd, buf, 0, actual, offset);
    return buf;
  }

  /** @param {number} finalSize */
  finalize(finalSize) {
    if (this.#fd !== null) fs.ftruncateSync(this.#fd, finalSize);
    this.#fileSize = finalSize;
  }

  close() {
    if (this.#fd !== null) {
      fs.closeSync(this.#fd);
      this.#fd = null;
    }
    this.#active = false;
  }
}
