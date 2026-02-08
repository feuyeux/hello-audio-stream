#include "memory/stream_manager.h"
#include "memory/memory_mapped_cache.h"
#include <chrono>
#include <filesystem>
#include <spdlog/spdlog.h>

namespace audio_stream {

StreamManager::StreamManager(const std::string &cacheDir)
    : cacheDir_(cacheDir) {
  // Create cache directory if it doesn't exist
  std::filesystem::create_directories(cacheDir);
  spdlog::info("StreamManager initialized with cache directory: {}", cacheDir);
}

StreamManager::~StreamManager() {
  // Cleanup all streams
  std::lock_guard<std::mutex> lock(mutex_);
  streams_.clear();
}

bool StreamManager::createStream(const std::string &streamId) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Check if stream already exists
  if (streams_.find(streamId) != streams_.end()) {
    spdlog::warn("Stream already exists: {}", streamId);
    return false;
  }

  try {
    // Create new stream context
    auto context = std::make_shared<StreamContext>();
    context->streamId = streamId;
    context->cachePath = getCachePath(streamId);
    context->currentOffset = 0;
    context->totalSize = 0;
    context->status = StreamStatus::UPLOADING;
    context->createdAt = std::chrono::system_clock::now();
    context->lastAccessedAt = context->createdAt;

    // Create memory-mapped cache file
    context->mmapFile = std::make_unique<MemoryMappedCache>(context->cachePath);

    // Add to registry
    streams_[streamId] = context;

    spdlog::info("Created stream: {} at path: {}", streamId,
                 context->cachePath);
    return true;
  } catch (const std::exception &e) {
    spdlog::error("Failed to create stream {}: {}", streamId, e.what());
    return false;
  }
}

std::shared_ptr<StreamContext>
StreamManager::getStream(const std::string &streamId) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto it = streams_.find(streamId);
  if (it != streams_.end()) {
    // Update last accessed time
    it->second->lastAccessedAt = std::chrono::system_clock::now();
    return it->second;
  }
  return nullptr;
}

bool StreamManager::deleteStream(const std::string &streamId) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = streams_.find(streamId);
  if (it == streams_.end()) {
    spdlog::warn("Stream not found for deletion: {}", streamId);
    return false;
  }

  try {
    // Close memory-mapped file
    it->second->mmapFile.reset();

    // Remove cache file
    std::filesystem::remove(it->second->cachePath);

    // Remove from registry
    streams_.erase(it);

    spdlog::info("Deleted stream: {}", streamId);
    return true;
  } catch (const std::exception &e) {
    spdlog::error("Failed to delete stream {}: {}", streamId, e.what());
    return false;
  }
}

std::vector<std::string> StreamManager::listActiveStreams() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<std::string> streamIds;
  for (const auto &pair : streams_) {
    streamIds.push_back(pair.first);
  }
  return streamIds;
}

bool StreamManager::writeChunk(const std::string &streamId,
                               const std::vector<uint8_t> &data) {
  auto stream = getStream(streamId);
  if (!stream) {
    spdlog::error("Stream not found for write: {}", streamId);
    return false;
  }

  std::lock_guard<std::mutex> streamLock(stream->contextMutex);

  if (stream->status != StreamStatus::UPLOADING) {
    spdlog::error("Stream {} is not in uploading state", streamId);
    return false;
  }

  try {
    // Write data to memory-mapped file
    if (stream->mmapFile->write(stream->currentOffset, data)) {
      stream->currentOffset += data.size();
      stream->totalSize += data.size();
      stream->lastAccessedAt = std::chrono::system_clock::now();

      // Keep UPLOADING status until stream is explicitly stopped (aligned with
      // Java server) Status only changes to READY in finalizeStream

      spdlog::debug("Wrote {} bytes to stream {} at offset {}", data.size(),
                    streamId, stream->currentOffset - data.size());
      return true;
    } else {
      spdlog::error("Failed to write data to stream {}", streamId);
      return false;
    }
  } catch (const std::exception &e) {
    spdlog::error("Error writing to stream {}: {}", streamId, e.what());
    return false;
  }
}

std::vector<uint8_t> StreamManager::readChunk(const std::string &streamId,
                                              size_t offset, size_t length) {
  auto stream = getStream(streamId);
  if (!stream) {
    spdlog::error("Stream not found for read: {}", streamId);
    return std::vector<uint8_t>();
  }

  std::lock_guard<std::mutex> streamLock(stream->contextMutex);

  // Align with Java server: don't check state, read directly from cache
  // Java server has no state management, can read as long as stream exists

  try {
    // Read data from memory-mapped file
    std::vector<uint8_t> data = stream->mmapFile->read(offset, length);
    stream->lastAccessedAt = std::chrono::system_clock::now();

    spdlog::debug("Read {} bytes from stream {} at offset {}", data.size(),
                  streamId, offset);
    return data;
  } catch (const std::exception &e) {
    spdlog::error("Error reading from stream {}: {}", streamId, e.what());
    return std::vector<uint8_t>();
  }
}

bool StreamManager::finalizeStream(const std::string &streamId) {
  auto stream = getStream(streamId);
  if (!stream) {
    spdlog::error("Stream not found for finalization: {}", streamId);
    return false;
  }

  std::lock_guard<std::mutex> streamLock(stream->contextMutex);

  if (stream->status != StreamStatus::UPLOADING) {
    spdlog::warn("Stream {} is not in uploading state for finalization",
                 streamId);
    return false;
  }

  try {
    // Finalize memory-mapped file (truncates to finalSize and flushes)
    if (stream->mmapFile->finalize(stream->totalSize)) {
      stream->status = StreamStatus::READY;
      stream->lastAccessedAt = std::chrono::system_clock::now();

      spdlog::info("Finalized stream: {} with {} bytes", streamId,
                   stream->totalSize);
      return true;
    } else {
      spdlog::error("Failed to finalize memory-mapped file for stream {}",
                    streamId);
      return false;
    }
  } catch (const std::exception &e) {
    spdlog::error("Error finalizing stream {}: {}", streamId, e.what());
    return false;
  }
}

void StreamManager::cleanupOldStreams() {
  std::lock_guard<std::mutex> lock(mutex_);

  auto now = std::chrono::system_clock::now();
  auto cutoff =
      now - std::chrono::hours(24); // Remove streams older than 24 hours

  auto it = streams_.begin();
  while (it != streams_.end()) {
    if (it->second->lastAccessedAt < cutoff) {
      spdlog::info("Cleaning up old stream: {}", it->first);

      try {
        // Close memory-mapped file
        it->second->mmapFile.reset();

        // Remove cache file
        std::filesystem::remove(it->second->cachePath);

        // Remove from registry
        it = streams_.erase(it);
      } catch (const std::exception &e) {
        spdlog::error("Error cleaning up stream {}: {}", it->first, e.what());
        ++it;
      }
    } else {
      ++it;
    }
  }
}

std::string StreamManager::getCachePath(const std::string &streamId) const {
  return cacheDir_ + "/" + streamId + ".cache";
}

} // namespace audio_stream
