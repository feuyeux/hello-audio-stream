#include "core/chunk_manager.h"
#include <algorithm>

namespace audio_stream {

std::vector<std::vector<uint8_t>>
ChunkManager::splitIntoChunks(const std::vector<uint8_t> &data) {
  std::vector<std::vector<uint8_t>> chunks;

  if (data.empty()) {
    return chunks;
  }

  size_t totalSize = data.size();
  size_t offset = 0;

  while (offset < totalSize) {
    size_t chunkSize = std::min(CHUNK_SIZE, totalSize - offset);

    std::vector<uint8_t> chunk(data.begin() + offset,
                               data.begin() + offset + chunkSize);
    chunks.push_back(std::move(chunk));

    offset += chunkSize;
  }

  return chunks;
}

size_t ChunkManager::calculateChunkCount(size_t totalSize) const {
  return (totalSize + CHUNK_SIZE - 1) / CHUNK_SIZE;
}

void ChunkManager::addChunk(size_t offset, const std::vector<uint8_t> &chunk) {
  chunks_.push_back({offset, chunk});
}

std::vector<uint8_t> ChunkManager::assembleChunks() {
  if (chunks_.empty()) {
    return std::vector<uint8_t>();
  }

  // Sort chunks by offset
  std::sort(chunks_.begin(), chunks_.end(),
            [](const auto &a, const auto &b) { return a.first < b.first; });

  // Calculate total size
  size_t totalSize = 0;
  for (const auto &chunk : chunks_) {
    totalSize += chunk.second.size();
  }

  // Assemble chunks
  std::vector<uint8_t> assembled;
  assembled.reserve(totalSize);

  for (const auto &chunk : chunks_) {
    assembled.insert(assembled.end(), chunk.second.begin(), chunk.second.end());
  }

  return assembled;
}

void ChunkManager::reset() { chunks_.clear(); }

} // namespace audio_stream
