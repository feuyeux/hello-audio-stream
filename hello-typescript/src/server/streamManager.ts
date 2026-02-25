import * as fs from 'fs';
import * as path from 'path';
import { MmapCache } from './mmapCache';

const MAX_STREAMS = 1000;
const MAX_IDLE_MS = 24 * 60 * 60 * 1000;       // 24 h
const MAX_UPLOADING_MS = 1 * 60 * 60 * 1000;   // 1 h

export type StreamStatus = 'UPLOADING' | 'READY' | 'ERROR';

/** A single audio stream with its mmap cache. */
interface Stream {
  id: string;
  cache: MmapCache;
  offset: number;
  created: number;
  lastAccess: number;
  status: StreamStatus;
}

/** Statistics snapshot. */
export interface Stats {
  total: number;
  uploading: number;
  ready: number;
  error: number;
}

/** Configuration for StreamManager. */
export interface Config {
  cacheDir: string;
  maxStreams?: number;
  maxIdleMs?: number;
  maxUploadingMs?: number;
}

/** Thread-safe (single-threaded Node.js) registry of audio streams. */
export class StreamManager {
  private readonly cacheDir: string;
  private readonly maxStreams: number;
  private readonly maxIdleMs: number;
  private readonly maxUploadingMs: number;
  private readonly streams = new Map<string, Stream>();

  constructor(config: Config) {
    this.cacheDir = config.cacheDir;
    this.maxStreams = config.maxStreams ?? MAX_STREAMS;
    this.maxIdleMs = config.maxIdleMs ?? MAX_IDLE_MS;
    this.maxUploadingMs = config.maxUploadingMs ?? MAX_UPLOADING_MS;
    fs.mkdirSync(this.cacheDir, { recursive: true });
  }

  /** Create a new uploading stream. */
  create(streamId: string): void {
    if (this.streams.size >= this.maxStreams) {
      throw new Error(`Max streams (${this.maxStreams}) reached`);
    }
    if (this.streams.has(streamId)) {
      throw new Error(`Stream already exists: ${streamId}`);
    }
    const cachePath = path.join(this.cacheDir, `${streamId}.cache`);
    const cache = new MmapCache(cachePath);
    cache.create();
    this.streams.set(streamId, {
      id: streamId,
      cache,
      offset: 0,
      created: Date.now(),
      lastAccess: Date.now(),
      status: 'UPLOADING',
    });
  }

  /** Append binary data to an uploading stream. */
  write(streamId: string, data: Buffer): void {
    const s = this.get(streamId);
    if (s.status !== 'UPLOADING') {
      throw new Error(`Stream ${streamId} is not uploading`);
    }
    s.cache.write(s.offset, data);
    s.offset += data.length;
    s.lastAccess = Date.now();
  }

  /** Finalize an uploading stream → READY. */
  complete(streamId: string): void {
    const s = this.get(streamId);
    if (s.status !== 'UPLOADING') {
      throw new Error(`Stream ${streamId} is not uploading`);
    }
    s.cache.finalize(s.offset);
    s.status = 'READY';
    s.lastAccess = Date.now();
  }

  /** Read bytes from a ready stream. */
  read(streamId: string, offset: number, length: number): Buffer {
    const s = this.get(streamId);
    if (s.status !== 'READY') {
      throw new Error(`Stream ${streamId} is not ready`);
    }
    s.lastAccess = Date.now();
    return s.cache.read(offset, length);
  }

  /** Delete a stream and remove its cache file. */
  delete(streamId: string): void {
    const s = this.get(streamId);
    s.cache.close();
    this.streams.delete(streamId);
    const cachePath = path.join(this.cacheDir, `${streamId}.cache`);
    if (fs.existsSync(cachePath)) fs.unlinkSync(cachePath);
  }

  /** Mark a stream as errored (e.g. on connection drop during upload). */
  markError(streamId: string): void {
    const s = this.streams.get(streamId);
    if (s && s.status === 'UPLOADING') s.status = 'ERROR';
  }

  /** Status and size of a stream. */
  statusOf(streamId: string): { status: StreamStatus; size: number } {
    const s = this.get(streamId);
    return { status: s.status, size: s.offset };
  }

  /** Comma-separated list of all stream IDs. */
  list(): string {
    return [...this.streams.keys()].join(',');
  }

  /** Remove stale streams. */
  cleanup(): void {
    const now = Date.now();
    for (const [id, s] of this.streams) {
      const idle = now - s.lastAccess;
      const uploading = now - s.created;
      const stale =
        (s.status === 'READY' || s.status === 'ERROR') && idle > this.maxIdleMs ||
        s.status === 'UPLOADING' && uploading > this.maxUploadingMs;
      if (stale) {
        s.cache.close();
        this.streams.delete(id);
        const p = path.join(this.cacheDir, `${id}.cache`);
        if (fs.existsSync(p)) fs.unlinkSync(p);
        console.error(`Cleaned up stream: ${id}`);
      }
    }
  }

  /** Aggregate statistics. */
  stats(): Stats {
    const s: Stats = { total: this.streams.size, uploading: 0, ready: 0, error: 0 };
    for (const st of this.streams.values()) {
      if (st.status === 'UPLOADING') s.uploading++;
      else if (st.status === 'READY') s.ready++;
      else s.error++;
    }
    return s;
  }

  private get(streamId: string): Stream {
    const s = this.streams.get(streamId);
    if (!s) throw new Error(`Stream not found: ${streamId}`);
    return s;
  }
}
