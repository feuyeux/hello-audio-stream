#ifndef AUDIO_STREAM_CHUNK_MANAGER_H
#define AUDIO_STREAM_CHUNK_MANAGER_H

#include "../../include/common_types.h"
#include <cstdint>
#include <vector>

namespace audio_stream {

/**
 * Chunk manager for splitting and assembling audio data
 * Handles chunking logic for upload and download operations
 */
class ChunkManager {
public:
  ChunkManager() = default;
  virtual ~ChunkManager() = default;

  // Upload chunking
  virtual std::vector<std::vector<uint8_t>>
  splitIntoChunks(const std::vector<uint8_t> &data);
  virtual size_t calculateChunkCount(size_t totalSize) const;

  // Download assembly
  virtual void addChunk(size_t offset, const std::vector<uint8_t> &chunk);
  virtual std::vector<uint8_t> assembleChunks();
  virtual void reset();

  // Utility
  virtual size_t getChunkSize() const { return CHUNK_SIZE; }

private:
  std::vector<std::pair<size_t, std::vector<uint8_t>>> chunks_;
  static constexpr size_t CHUNK_SIZE = 65536; // 64KB chunks
};

} // namespace audio_stream

#endif // AUDIO_STREAM_CHUNK_MANAGER_H
