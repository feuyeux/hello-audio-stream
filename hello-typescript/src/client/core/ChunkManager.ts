/**
 * Chunk manager for handling data chunking operations.
 * Provides utilities for chunk size calculations and data splitting.
 * Matches Java ChunkManager functionality.
 */

export class ChunkManager {
  private static readonly DEFAULT_CHUNK_SIZE = 65536; // 64KB
  private static readonly UPLOAD_CHUNK_SIZE = 8192; // 8KB for upload to avoid WebSocket fragmentation

  getDefaultChunkSize(): number {
    return ChunkManager.DEFAULT_CHUNK_SIZE;
  }

  getUploadChunkSize(): number {
    return ChunkManager.UPLOAD_CHUNK_SIZE;
  }

  calculateChunkCount(fileSize: number, chunkSize: number): number {
    return Math.ceil(fileSize / chunkSize);
  }

  getChunkSize(
    fileSize: number,
    offset: number,
    defaultChunkSize: number,
  ): number {
    const remainingBytes = fileSize - offset;
    return Math.min(defaultChunkSize, remainingBytes);
  }
}
