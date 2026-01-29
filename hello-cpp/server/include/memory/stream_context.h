#ifndef AUDIO_STREAM_STREAM_CONTEXT_H
#define AUDIO_STREAM_STREAM_CONTEXT_H

#include "common_types.h"
#include "memory/memory_mapped_cache.h"
#include <chrono>
#include <memory>
#include <mutex>
#include <string>

namespace audio_stream {

/**
 * Stream context for managing active audio streams
 * Contains stream metadata and cache file handle
 */
struct StreamContext {
  std::string streamId;
  std::string cachePath;
  std::unique_ptr<MemoryMappedCache> mmapFile;
  size_t currentOffset = 0;
  size_t totalSize = 0;
  std::chrono::system_clock::time_point createdAt;
  std::chrono::system_clock::time_point lastAccessedAt;
  StreamStatus status = StreamStatus::UPLOADING;

  /// Mutex for thread-safe access to stream context fields
  mutable std::mutex contextMutex;

  StreamContext()
      : createdAt(std::chrono::system_clock::now()),
        lastAccessedAt(std::chrono::system_clock::now()) {}

  StreamContext(const std::string &id)
      : streamId(id), createdAt(std::chrono::system_clock::now()),
        lastAccessedAt(std::chrono::system_clock::now()) {}
};

} // namespace audio_stream

#endif // AUDIO_STREAM_STREAM_CONTEXT_H
