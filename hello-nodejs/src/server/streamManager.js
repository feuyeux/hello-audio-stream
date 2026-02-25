// Registry of active audio streams.
import * as fs from 'fs';
import * as path from 'path';
import { MmapCache } from './mmapCache.js';

const MAX_STREAMS = 1000;
const MAX_IDLE_MS = 24 * 60 * 60 * 1000;
const MAX_UPLOADING_MS = 60 * 60 * 1000;

export class StreamManager {
  #cacheDir;
  #maxStreams;
  #maxIdleMs;
  #maxUploadingMs;
  /** @type {Map<string, {id:string, cache:MmapCache, offset:number, created:number, lastAccess:number, status:string}>} */
  #streams = new Map();

  constructor({ cacheDir, maxStreams = MAX_STREAMS, maxIdleMs = MAX_IDLE_MS, maxUploadingMs = MAX_UPLOADING_MS }) {
    this.#cacheDir = cacheDir;
    this.#maxStreams = maxStreams;
    this.#maxIdleMs = maxIdleMs;
    this.#maxUploadingMs = maxUploadingMs;
    fs.mkdirSync(this.#cacheDir, { recursive: true });
  }

  create(streamId) {
    if (this.#streams.size >= this.#maxStreams) throw new Error(`Max streams (${this.#maxStreams}) reached`);
    if (this.#streams.has(streamId)) throw new Error(`Stream already exists: ${streamId}`);
    const cachePath = path.join(this.#cacheDir, `${streamId}.cache`);
    const cache = new MmapCache(cachePath);
    cache.create();
    this.#streams.set(streamId, { id: streamId, cache, offset: 0, created: Date.now(), lastAccess: Date.now(), status: 'UPLOADING' });
  }

  write(streamId, data) {
    const s = this.#get(streamId);
    if (s.status !== 'UPLOADING') throw new Error(`Stream ${streamId} is not uploading`);
    s.cache.write(s.offset, data);
    s.offset += data.length;
    s.lastAccess = Date.now();
  }

  complete(streamId) {
    const s = this.#get(streamId);
    if (s.status !== 'UPLOADING') throw new Error(`Stream ${streamId} is not uploading`);
    s.cache.finalize(s.offset);
    s.status = 'READY';
    s.lastAccess = Date.now();
  }

  read(streamId, offset, length) {
    const s = this.#get(streamId);
    if (s.status !== 'READY') throw new Error(`Stream ${streamId} is not ready`);
    s.lastAccess = Date.now();
    return s.cache.read(offset, length);
  }

  delete(streamId) {
    const s = this.#get(streamId);
    s.cache.close();
    this.#streams.delete(streamId);
    const p = path.join(this.#cacheDir, `${streamId}.cache`);
    if (fs.existsSync(p)) fs.unlinkSync(p);
  }

  markError(streamId) {
    const s = this.#streams.get(streamId);
    if (s && s.status === 'UPLOADING') s.status = 'ERROR';
  }

  statusOf(streamId) {
    const s = this.#get(streamId);
    return { status: s.status, size: s.offset };
  }

  list() {
    return [...this.#streams.keys()].join(',');
  }

  cleanup() {
    const now = Date.now();
    for (const [id, s] of this.#streams) {
      const stale =
        ((s.status === 'READY' || s.status === 'ERROR') && (now - s.lastAccess) > this.#maxIdleMs) ||
        (s.status === 'UPLOADING' && (now - s.created) > this.#maxUploadingMs);
      if (stale) {
        s.cache.close();
        this.#streams.delete(id);
        const p = path.join(this.#cacheDir, `${id}.cache`);
        if (fs.existsSync(p)) fs.unlinkSync(p);
        console.error(`Cleaned up stream: ${id}`);
      }
    }
  }

  stats() {
    let uploading = 0, ready = 0, error = 0;
    for (const s of this.#streams.values()) {
      if (s.status === 'UPLOADING') uploading++;
      else if (s.status === 'READY') ready++;
      else error++;
    }
    return { total: this.#streams.size, uploading, ready, error };
  }

  #get(streamId) {
    const s = this.#streams.get(streamId);
    if (!s) throw new Error(`Stream not found: ${streamId}`);
    return s;
  }
}
