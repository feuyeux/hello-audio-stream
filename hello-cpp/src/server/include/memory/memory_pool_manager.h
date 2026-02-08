#ifndef AUDIO_STREAM_MEMORY_POOL_MANAGER_H
#define AUDIO_STREAM_MEMORY_POOL_MANAGER_H

#include "../include/common_types.h"
#include <cstdint>
#include <memory>
#include <mutex>
#include <queue>
#include <vector>

namespace audio_stream {

/**
 * Memory pool manager for efficient buffer reuse
 * Pre-allocates buffers to minimize allocation overhead
 * Implemented as a singleton to ensure a single shared pool across all streams
 */
class MemoryPoolManager {
public:
  // Singleton access
  static MemoryPoolManager &getInstance(size_t bufferSize = 65536,
                                        size_t poolSize = 100);

  // Delete copy and move constructors/operators
  MemoryPoolManager(const MemoryPoolManager &) = delete;
  MemoryPoolManager &operator=(const MemoryPoolManager &) = delete;
  MemoryPoolManager(MemoryPoolManager &&) = delete;
  MemoryPoolManager &operator=(MemoryPoolManager &&) = delete;

  // Buffer management
  std::shared_ptr<std::vector<uint8_t>> acquireBuffer();
  void releaseBuffer(std::shared_ptr<std::vector<uint8_t>> buffer);

  // Statistics
  size_t getAvailableBuffers() const;
  size_t getTotalBuffers() const;

private:
  // Private constructor for singleton
  MemoryPoolManager(size_t bufferSize, size_t poolSize);
  ~MemoryPoolManager();

  size_t bufferSize_;
  size_t poolSize_;
  std::queue<std::shared_ptr<std::vector<uint8_t>>> availableBuffers_;
  mutable std::mutex mutex_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_MEMORY_POOL_MANAGER_H
