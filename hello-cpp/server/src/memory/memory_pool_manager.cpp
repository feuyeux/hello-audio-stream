#include "memory/memory_pool_manager.h"
#include <spdlog/spdlog.h>

namespace audio_stream {

MemoryPoolManager &MemoryPoolManager::getInstance(size_t bufferSize,
                                                  size_t poolSize) {
  static MemoryPoolManager instance(bufferSize, poolSize);
  return instance;
}

MemoryPoolManager::MemoryPoolManager(size_t bufferSize, size_t poolSize)
    : bufferSize_(bufferSize), poolSize_(poolSize) {

  // Pre-allocate buffers
  for (size_t i = 0; i < poolSize; ++i) {
    auto buffer = std::make_shared<std::vector<uint8_t>>(bufferSize);
    availableBuffers_.push(buffer);
  }

  spdlog::info("MemoryPoolManager initialized with {} buffers of {} bytes",
               poolSize, bufferSize);
}

MemoryPoolManager::~MemoryPoolManager() {
  std::lock_guard<std::mutex> lock(mutex_);
  while (!availableBuffers_.empty()) {
    availableBuffers_.pop();
  }
}

std::shared_ptr<std::vector<uint8_t>> MemoryPoolManager::acquireBuffer() {
  std::lock_guard<std::mutex> lock(mutex_);

  if (availableBuffers_.empty()) {
    // Pool exhausted, allocate new buffer
    spdlog::warn("Memory pool exhausted, allocating new buffer");
    return std::make_shared<std::vector<uint8_t>>(bufferSize_);
  }

  auto buffer = availableBuffers_.front();
  availableBuffers_.pop();
  buffer->clear();
  buffer->resize(bufferSize_);

  return buffer;
}

void MemoryPoolManager::releaseBuffer(
    std::shared_ptr<std::vector<uint8_t>> buffer) {
  if (!buffer)
    return;

  std::lock_guard<std::mutex> lock(mutex_);

  // Only return to pool if we haven't exceeded pool size
  if (availableBuffers_.size() < poolSize_) {
    buffer->clear();
    availableBuffers_.push(buffer);
  }
}

size_t MemoryPoolManager::getAvailableBuffers() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return availableBuffers_.size();
}

size_t MemoryPoolManager::getTotalBuffers() const { return poolSize_; }

} // namespace audio_stream
