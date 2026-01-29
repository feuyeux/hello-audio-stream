#ifndef AUDIO_STREAM_MEMORY_MAPPED_CACHE_H
#define AUDIO_STREAM_MEMORY_MAPPED_CACHE_H

#include <cstdint>
#include <map>
#include <shared_mutex>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#endif

namespace audio_stream {

/**
 * Memory-mapped file cache for efficient data storage.
 * Provides zero-copy read/write access to cached files.
 * Follows the unified mmap implementation specification v2.0.0.
 *
 * Key Features:
 * - Large file support (>2GB) using 64-bit offsets
 * - Batch operations for improved I/O efficiency
 * - Thread-safe operations with read-write locks
 * - Memory management with flush/prefetch/evict
 * - Cross-platform support (Windows/POSIX)
 *
 * @version 2.0.0
 */
class MemoryMappedCache {
public:
  // Configuration constants
  static constexpr uint64_t SEGMENT_SIZE =
      1ULL * 1024 * 1024 * 1024; // 1GB per segment
  static constexpr uint64_t MAX_CACHE_SIZE =
      8ULL * 1024 * 1024 * 1024; // 8GB total
  static constexpr size_t BATCH_OPERATION_LIMIT = 1000;

  /**
   * Write operation for batch processing.
   */
  struct WriteOperation {
    uint64_t offset;
    std::vector<uint8_t> data;
  };

  /**
   * Read operation for batch processing.
   */
  struct ReadOperation {
    uint64_t offset;
    size_t length;
  };

  explicit MemoryMappedCache(const std::string &filePath);
  ~MemoryMappedCache();

  // Disable copy and move
  MemoryMappedCache(const MemoryMappedCache &) = delete;
  MemoryMappedCache &operator=(const MemoryMappedCache &) = delete;

  // File operations
  bool create(uint64_t initialSize = 0);
  bool open();
  void close();

  // Data operations
  size_t write(uint64_t offset, const std::vector<uint8_t> &data);
  std::vector<uint8_t> read(uint64_t offset, size_t length);

  // Batch operations
  std::vector<size_t> writeBatch(const std::vector<WriteOperation> &operations);
  std::vector<std::vector<uint8_t>>
  readBatch(const std::vector<ReadOperation> &operations);

  // Advanced operations
  bool resize(uint64_t newSize);
  bool finalize(uint64_t finalSize);
  bool flush();
  bool prefetch(uint64_t offset, size_t length);
  bool evict(uint64_t offset, size_t length);

  // Utility
  uint64_t getSize() const;
  std::string getFilePath() const;
  bool isOpen() const;

private:
  // Internal methods
  bool mapSegment(uint64_t segmentIndex);
  void unmapAllSegments();
  void *getSegmentAddress(uint64_t segmentIndex);
  bool validateOffset(uint64_t offset, size_t length) const;
  void logError(const std::string &operation, const std::string &error) const;

  // Member variables
  std::string filePath_;
  uint64_t fileSize_;
  bool isOpen_;
  mutable std::shared_mutex rwMutex_;
  std::map<uint64_t, void *> segments_;

#ifdef _WIN32
  HANDLE fileHandle_;
  std::map<uint64_t, HANDLE> mappingHandles_;
#else
  int fileDescriptor_;
#endif
};

} // namespace audio_stream

#endif // AUDIO_STREAM_MEMORY_MAPPED_CACHE_H
