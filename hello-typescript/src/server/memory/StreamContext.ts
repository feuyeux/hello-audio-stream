/**
 * Stream context for managing active audio streams.
 * Contains stream metadata and cache file handle.
 * Matches C++ StreamContext structure and Java StreamContext class.
 */

import { MemoryMappedCache } from "./MemoryMappedCache";

export enum StreamStatus {
  UPLOADING = "UPLOADING",
  READY = "READY",
  ERROR = "ERROR",
}

export class StreamContext {
  streamId: string;
  cachePath: string;
  mmapFile: MemoryMappedCache | null;
  currentOffset: number;
  totalSize: number;
  createdAt: Date;
  lastAccessedAt: Date;
  status: StreamStatus;

  constructor(streamId: string) {
    this.streamId = streamId;
    this.cachePath = "";
    this.mmapFile = null;
    this.currentOffset = 0;
    this.totalSize = 0;
    this.createdAt = new Date();
    this.lastAccessedAt = new Date();
    this.status = StreamStatus.UPLOADING;
  }

  updateAccessTime(): void {
    this.lastAccessedAt = new Date();
  }
}
