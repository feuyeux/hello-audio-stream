/**
 * Stream manager for managing active audio streams.
 * Thread-safe registry of stream contexts.
 * Matches C++ StreamManager and Java StreamManager functionality.
 */

import * as fs from "fs";
import * as path from "path";
import { StreamContext, StreamStatus } from "./StreamContext";
import { MemoryMappedCache } from "./MemoryMappedCache";

export class StreamManager {
  private static instance: StreamManager | null = null;
  private cacheDirectory: string;
  private streams: Map<string, StreamContext>;

  private constructor(cacheDirectory: string = "cache") {
    this.cacheDirectory = cacheDirectory;
    this.streams = new Map();

    // Create cache directory if it doesn't exist
    if (!fs.existsSync(cacheDirectory)) {
      fs.mkdirSync(cacheDirectory, { recursive: true });
    }

    console.log(
      `StreamManager initialized with cache directory: ${cacheDirectory}`,
    );
  }

  static getInstance(cacheDirectory: string = "cache"): StreamManager {
    if (!StreamManager.instance) {
      StreamManager.instance = new StreamManager(cacheDirectory);
    }
    return StreamManager.instance;
  }

  createStream(streamId: string): boolean {
    // Check if stream already exists
    if (this.streams.has(streamId)) {
      console.warn(`Stream already exists: ${streamId}`);
      return false;
    }

    try {
      // Create new stream context
      const cachePath = this.getCachePath(streamId);
      const context = new StreamContext(streamId);
      context.cachePath = cachePath;
      context.currentOffset = 0;
      context.totalSize = 0;
      context.status = StreamStatus.UPLOADING;
      context.createdAt = new Date();
      context.lastAccessedAt = new Date();

      // Create memory-mapped cache file
      const mmapFile = new MemoryMappedCache(cachePath);
      context.mmapFile = mmapFile;

      // Add to registry
      this.streams.set(streamId, context);

      console.log(`Created stream: ${streamId} at path: ${cachePath}`);
      return true;
    } catch (error) {
      console.error(`Failed to create stream ${streamId}:`, error);
      return false;
    }
  }

  getStream(streamId: string): StreamContext | null {
    const context = this.streams.get(streamId);
    if (context) {
      context.updateAccessTime();
    }
    return context || null;
  }

  deleteStream(streamId: string): boolean {
    const context = this.streams.get(streamId);
    if (!context) {
      console.warn(`Stream not found for deletion: ${streamId}`);
      return false;
    }

    try {
      // Close memory-mapped file
      if (context.mmapFile) {
        context.mmapFile.close();
      }

      // Remove cache file
      if (fs.existsSync(context.cachePath)) {
        fs.unlinkSync(context.cachePath);
      }

      // Remove from registry
      this.streams.delete(streamId);

      console.log(`Deleted stream: ${streamId}`);
      return true;
    } catch (error) {
      console.error(`Failed to delete stream ${streamId}:`, error);
      return false;
    }
  }

  listActiveStreams(): string[] {
    return Array.from(this.streams.keys());
  }

  writeChunk(streamId: string, data: Buffer): boolean {
    const stream = this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for write: ${streamId}`);
      return false;
    }

    if (stream.status !== StreamStatus.UPLOADING) {
      console.error(`Stream ${streamId} is not in uploading state`);
      return false;
    }

    try {
      // Write data to memory-mapped file
      if (!stream.mmapFile) {
        return false;
      }

      const written = stream.mmapFile.write(stream.currentOffset, data);

      if (written > 0) {
        stream.currentOffset += written;
        stream.totalSize += written;
        stream.updateAccessTime();

        console.log(
          `Wrote ${written} bytes to stream ${streamId} at offset ${stream.currentOffset - written}`,
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

  readChunk(streamId: string, offset: number, length: number): Buffer {
    const stream = this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for read: ${streamId}`);
      return Buffer.alloc(0);
    }

    try {
      // Read data from memory-mapped file
      if (!stream.mmapFile) {
        return Buffer.alloc(0);
      }

      const data = stream.mmapFile.read(offset, length);
      stream.updateAccessTime();

      console.log(
        `Read ${data.length} bytes from stream ${streamId} at offset ${offset}`,
      );
      return data;
    } catch (error) {
      console.error(`Error reading from stream ${streamId}:`, error);
      return Buffer.alloc(0);
    }
  }

  finalizeStream(streamId: string): boolean {
    const stream = this.getStream(streamId);
    if (!stream) {
      console.error(`Stream not found for finalization: ${streamId}`);
      return false;
    }

    if (stream.status !== StreamStatus.UPLOADING) {
      console.warn(
        `Stream ${streamId} is not in uploading state for finalization`,
      );
      return false;
    }

    try {
      // Finalize memory-mapped file
      if (!stream.mmapFile) {
        return false;
      }

      if (stream.mmapFile.finalize(stream.totalSize)) {
        stream.status = StreamStatus.READY;
        stream.updateAccessTime();

        console.log(
          `Finalized stream: ${streamId} with ${stream.totalSize} bytes`,
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

  cleanupOldStreams(maxAgeHours: number = 24): void {
    const now = new Date();
    const cutoffMs = maxAgeHours * 60 * 60 * 1000;

    const toRemove: string[] = [];
    for (const [streamId, context] of this.streams.entries()) {
      const age = now.getTime() - context.lastAccessedAt.getTime();
      if (age > cutoffMs) {
        toRemove.push(streamId);
      }
    }

    for (const streamId of toRemove) {
      console.log(`Cleaning up old stream: ${streamId}`);
      this.deleteStream(streamId);
    }
  }

  private getCachePath(streamId: string): string {
    return path.join(this.cacheDirectory, `${streamId}.cache`);
  }
}
