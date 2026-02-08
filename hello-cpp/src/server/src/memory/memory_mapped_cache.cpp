#include "memory/memory_mapped_cache.h"
#include <algorithm>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <spdlog/spdlog.h>

#ifdef _WIN32
// Windows headers already included in header file
#else
#include <errno.h>
#endif

namespace audio_stream {

MemoryMappedCache::MemoryMappedCache(const std::string &filePath)
    : filePath_(filePath), fileSize_(0), isOpen_(false)
#ifdef _WIN32
      ,
      fileHandle_(INVALID_HANDLE_VALUE)
#else
      ,
      fileDescriptor_(-1)
#endif
{
  spdlog::debug("MemoryMappedCache created for: {}", filePath);
}

MemoryMappedCache::~MemoryMappedCache() { close(); }

bool MemoryMappedCache::create(uint64_t initialSize) {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  try {
    if (!validateOffset(0, initialSize)) {
      return false;
    }

    spdlog::debug("Creating mmap file: {} with initial size: {}", filePath_,
                  initialSize);

    // Create the file
    std::ofstream file(filePath_, std::ios::binary);
    if (!file) {
      logError("create", "Failed to create file");
      return false;
    }

    // Pre-allocate space if requested
    if (initialSize > 0) {
      file.seekp(initialSize - 1);
      file.write("", 1);
      fileSize_ = initialSize;
    } else {
      fileSize_ = 0;
    }

    file.close();

#ifdef _WIN32
    // Open file handle for Windows
    fileHandle_ = CreateFileA(filePath_.c_str(), GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                              OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);

    if (fileHandle_ == INVALID_HANDLE_VALUE) {
      logError("create", "Failed to open file handle");
      return false;
    }
#else
    // Open file descriptor for POSIX
    fileDescriptor_ = ::open(filePath_.c_str(), O_RDWR);
    if (fileDescriptor_ == -1) {
      logError("create",
               std::string("Failed to open file: ") + strerror(errno));
      return false;
    }
#endif

    isOpen_ = true;
    spdlog::debug("Created mmap file: {} with size: {}", filePath_,
                  initialSize);
    return true;

  } catch (const std::exception &e) {
    logError("create", e.what());
    return false;
  }
}

bool MemoryMappedCache::open() {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  try {
    spdlog::debug("Opening mmap file: {}", filePath_);

    // Check if file exists
    if (!std::filesystem::exists(filePath_)) {
      logError("open", "File does not exist");
      return false;
    }

    // Get file size
    fileSize_ = std::filesystem::file_size(filePath_);

#ifdef _WIN32
    fileHandle_ = CreateFileA(filePath_.c_str(), GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                              OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);

    if (fileHandle_ == INVALID_HANDLE_VALUE) {
      logError("open", "Failed to open file handle");
      return false;
    }
#else
    fileDescriptor_ = ::open(filePath_.c_str(), O_RDWR);
    if (fileDescriptor_ == -1) {
      logError("open", std::string("Failed to open file: ") + strerror(errno));
      return false;
    }
#endif

    isOpen_ = true;
    spdlog::debug("Opened mmap file: {} with size: {}", filePath_, fileSize_);
    return true;

  } catch (const std::exception &e) {
    logError("open", e.what());
    return false;
  }
}

void MemoryMappedCache::close() {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  if (isOpen_) {
    unmapAllSegments();

#ifdef _WIN32
    if (fileHandle_ != INVALID_HANDLE_VALUE) {
      CloseHandle(fileHandle_);
      fileHandle_ = INVALID_HANDLE_VALUE;
    }
#else
    if (fileDescriptor_ >= 0) {
      ::close(fileDescriptor_);
      fileDescriptor_ = -1;
    }
#endif

    isOpen_ = false;
    spdlog::debug("Closed mmap file: {}", filePath_);
  }
}

size_t MemoryMappedCache::write(uint64_t offset,
                                const std::vector<uint8_t> &data) {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  try {
    // Auto-create if not open
    if (!isOpen_) {
      lock.unlock();
      uint64_t initialSize = offset + data.size();
      if (!create(initialSize)) {
        return 0;
      }
      lock.lock();
    }

    if (!validateOffset(offset, data.size())) {
      return 0;
    }

    // Resize if needed
    uint64_t requiredSize = offset + data.size();
    if (requiredSize > fileSize_) {
      lock.unlock();
      if (!resize(requiredSize)) {
        logError("write", "Failed to resize file");
        return 0;
      }
      lock.lock();
    }

    // Write to appropriate segment(s)
    size_t bytesWritten = 0;
    uint64_t currentOffset = offset;
    size_t dataOffset = 0;

    while (dataOffset < data.size()) {
      uint64_t segmentIndex = currentOffset / SEGMENT_SIZE;
      uint64_t segmentOffset = currentOffset % SEGMENT_SIZE;
      size_t bytesToWrite =
          std::min(data.size() - dataOffset,
                   static_cast<size_t>(SEGMENT_SIZE - segmentOffset));

      if (!mapSegment(segmentIndex)) {
        logError("write", "Failed to map segment");
        break;
      }

      void *segmentAddr = getSegmentAddress(segmentIndex);
      if (!segmentAddr) {
        logError("write", "Invalid segment address");
        break;
      }

      uint8_t *writePtr = static_cast<uint8_t *>(segmentAddr) + segmentOffset;
      std::memcpy(writePtr, data.data() + dataOffset, bytesToWrite);

      // Flush to disk
#ifdef _WIN32
      FlushViewOfFile(writePtr, bytesToWrite);
#else
      msync(writePtr, bytesToWrite, MS_ASYNC);
#endif

      currentOffset += bytesToWrite;
      dataOffset += bytesToWrite;
      bytesWritten += bytesToWrite;
    }

    spdlog::debug("Wrote {} bytes to {} at offset {}", bytesWritten, filePath_,
                  offset);
    return bytesWritten;

  } catch (const std::exception &e) {
    logError("write", e.what());
    return 0;
  }
}

std::vector<uint8_t> MemoryMappedCache::read(uint64_t offset, size_t length) {
  std::shared_lock<std::shared_mutex> lock(rwMutex_);

  try {
    // Auto-open if not open
    if (!isOpen_) {
      lock.unlock();
      std::unique_lock<std::shared_mutex> wlock(rwMutex_);
      if (!isOpen_) {
        spdlog::debug("File not open, attempting to open for reading: {}",
                      filePath_);
        if (!open()) {
          logError("read", "Failed to open file");
          return std::vector<uint8_t>();
        }
      }
      wlock.unlock();
      lock.lock();
    }

    // Check bounds
    if (offset >= fileSize_) {
      spdlog::debug("Read offset {} at or beyond file size {} - end of file",
                    offset, fileSize_);
      return std::vector<uint8_t>();
    }

    // Adjust length if needed
    size_t actualLength =
        std::min(length, static_cast<size_t>(fileSize_ - offset));
    std::vector<uint8_t> result(actualLength);

    // Read from appropriate segment(s)
    uint64_t currentOffset = offset;
    size_t bytesRead = 0;

    while (bytesRead < actualLength) {
      uint64_t segmentIndex = currentOffset / SEGMENT_SIZE;
      uint64_t segmentOffset = currentOffset % SEGMENT_SIZE;
      size_t bytesToRead =
          std::min(actualLength - bytesRead,
                   static_cast<size_t>(SEGMENT_SIZE - segmentOffset));

      if (!const_cast<MemoryMappedCache *>(this)->mapSegment(segmentIndex)) {
        logError("read", "Failed to map segment");
        break;
      }

      void *segmentAddr =
          const_cast<MemoryMappedCache *>(this)->getSegmentAddress(
              segmentIndex);
      if (!segmentAddr) {
        logError("read", "Invalid segment address");
        break;
      }

      const uint8_t *readPtr =
          static_cast<const uint8_t *>(segmentAddr) + segmentOffset;
      std::memcpy(result.data() + bytesRead, readPtr, bytesToRead);

      currentOffset += bytesToRead;
      bytesRead += bytesToRead;
    }

    result.resize(bytesRead);
    spdlog::debug("Read {} bytes from {} at offset {}", bytesRead, filePath_,
                  offset);
    return result;

  } catch (const std::exception &e) {
    logError("read", e.what());
    return std::vector<uint8_t>();
  }
}

std::vector<size_t>
MemoryMappedCache::writeBatch(const std::vector<WriteOperation> &operations) {
  if (operations.size() > BATCH_OPERATION_LIMIT) {
    spdlog::error("Batch operation limit exceeded: {}", operations.size());
    return std::vector<size_t>();
  }

  std::vector<size_t> results;
  results.reserve(operations.size());

  for (const auto &op : operations) {
    size_t written = write(op.offset, op.data);
    results.push_back(written);
  }

  return results;
}

std::vector<std::vector<uint8_t>>
MemoryMappedCache::readBatch(const std::vector<ReadOperation> &operations) {
  if (operations.size() > BATCH_OPERATION_LIMIT) {
    spdlog::error("Batch operation limit exceeded: {}", operations.size());
    return std::vector<std::vector<uint8_t>>();
  }

  std::vector<std::vector<uint8_t>> results;
  results.reserve(operations.size());

  for (const auto &op : operations) {
    auto data = read(op.offset, op.length);
    results.push_back(std::move(data));
  }

  return results;
}

bool MemoryMappedCache::resize(uint64_t newSize) {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  try {
    if (!isOpen_) {
      logError("resize", "File not open");
      return false;
    }

    if (!validateOffset(0, newSize)) {
      return false;
    }

    if (newSize == fileSize_) {
      return true;
    }

    // Unmap all segments before resizing
    unmapAllSegments();

    // Resize the file
    std::filesystem::resize_file(filePath_, newSize);
    fileSize_ = newSize;

    spdlog::debug("Resized file {} to {} bytes", filePath_, newSize);
    return true;

  } catch (const std::exception &e) {
    logError("resize", e.what());
    return false;
  }
}

bool MemoryMappedCache::finalize(uint64_t finalSize) {
  try {
    if (!isOpen_) {
      spdlog::warn("File not open for finalization: {}", filePath_);
      return false;
    }

    if (!resize(finalSize)) {
      logError("finalize", "Failed to resize file");
      return false;
    }

    if (!flush()) {
      logError("finalize", "Failed to flush file");
      return false;
    }

    spdlog::debug("Finalized file: {} with size: {}", filePath_, finalSize);
    return true;

  } catch (const std::exception &e) {
    logError("finalize", e.what());
    return false;
  }
}

bool MemoryMappedCache::flush() {
  std::shared_lock<std::shared_mutex> lock(rwMutex_);

  try {
    if (!isOpen_) {
      spdlog::warn("File not open for flush: {}", filePath_);
      return false;
    }

    for (const auto &[index, addr] : segments_) {
      if (addr) {
#ifdef _WIN32
        FlushViewOfFile(addr, 0);
#else
        uint64_t segmentSize =
            std::min(SEGMENT_SIZE, fileSize_ - index * SEGMENT_SIZE);
        msync(addr, segmentSize, MS_SYNC);
#endif
      }
    }

    spdlog::debug("Flushed file: {}", filePath_);
    return true;

  } catch (const std::exception &e) {
    logError("flush", e.what());
    return false;
  }
}

bool MemoryMappedCache::prefetch(uint64_t offset, size_t length) {
  std::shared_lock<std::shared_mutex> lock(rwMutex_);

  try {
    if (!isOpen_) {
      spdlog::warn("File not open for prefetch: {}", filePath_);
      return false;
    }

    if (!validateOffset(offset, length)) {
      return false;
    }

    // Prefetch segments
    uint64_t startSegment = offset / SEGMENT_SIZE;
    uint64_t endSegment = (offset + length - 1) / SEGMENT_SIZE;

    for (uint64_t segmentIndex = startSegment; segmentIndex <= endSegment;
         segmentIndex++) {
      if (!const_cast<MemoryMappedCache *>(this)->mapSegment(segmentIndex)) {
        logError("prefetch", "Failed to map segment");
        return false;
      }

#ifndef _WIN32
      void *addr = const_cast<MemoryMappedCache *>(this)->getSegmentAddress(
          segmentIndex);
      if (addr) {
        uint64_t segmentSize =
            std::min(SEGMENT_SIZE, fileSize_ - segmentIndex * SEGMENT_SIZE);
        madvise(addr, segmentSize, MADV_WILLNEED);
      }
#endif
    }

    spdlog::debug("Prefetched {} bytes from {} at offset {}", length, filePath_,
                  offset);
    return true;

  } catch (const std::exception &e) {
    logError("prefetch", e.what());
    return false;
  }
}

bool MemoryMappedCache::evict(uint64_t offset, size_t length) {
  std::unique_lock<std::shared_mutex> lock(rwMutex_);

  try {
    if (!isOpen_) {
      spdlog::warn("File not open for evict: {}", filePath_);
      return false;
    }

    if (!validateOffset(offset, length)) {
      return false;
    }

    // Evict segments
    uint64_t startSegment = offset / SEGMENT_SIZE;
    uint64_t endSegment = (offset + length - 1) / SEGMENT_SIZE;

    for (uint64_t segmentIndex = startSegment; segmentIndex <= endSegment;
         segmentIndex++) {
      auto it = segments_.find(segmentIndex);
      if (it != segments_.end()) {
        void *addr = it->second;

#ifdef _WIN32
        UnmapViewOfFile(addr);
        auto handleIt = mappingHandles_.find(segmentIndex);
        if (handleIt != mappingHandles_.end()) {
          CloseHandle(handleIt->second);
          mappingHandles_.erase(handleIt);
        }
#else
        uint64_t segmentSize =
            std::min(SEGMENT_SIZE, fileSize_ - segmentIndex * SEGMENT_SIZE);
        munmap(addr, segmentSize);
#endif

        segments_.erase(it);
      }
    }

    spdlog::debug("Evicted {} bytes from {} at offset {}", length, filePath_,
                  offset);
    return true;

  } catch (const std::exception &e) {
    logError("evict", e.what());
    return false;
  }
}

uint64_t MemoryMappedCache::getSize() const { return fileSize_; }

std::string MemoryMappedCache::getFilePath() const { return filePath_; }

bool MemoryMappedCache::isOpen() const { return isOpen_; }

// Private methods

bool MemoryMappedCache::mapSegment(uint64_t segmentIndex) {
  // Check if already mapped
  if (segments_.find(segmentIndex) != segments_.end()) {
    return true;
  }

  try {
    uint64_t segmentOffset = segmentIndex * SEGMENT_SIZE;
    uint64_t segmentSize = std::min(SEGMENT_SIZE, fileSize_ - segmentOffset);

    if (segmentSize == 0) {
      logError("mapSegment", "Invalid segment size");
      return false;
    }

#ifdef _WIN32
    HANDLE mappingHandle = CreateFileMappingA(
        fileHandle_, nullptr, PAGE_READWRITE,
        static_cast<DWORD>(segmentSize >> 32),
        static_cast<DWORD>(segmentSize & 0xFFFFFFFF), nullptr);

    if (mappingHandle == nullptr) {
      logError("mapSegment", "Failed to create file mapping");
      return false;
    }

    void *addr = MapViewOfFile(mappingHandle, FILE_MAP_ALL_ACCESS,
                               static_cast<DWORD>(segmentOffset >> 32),
                               static_cast<DWORD>(segmentOffset & 0xFFFFFFFF),
                               segmentSize);

    if (addr == nullptr) {
      CloseHandle(mappingHandle);
      logError("mapSegment", "Failed to map view of file");
      return false;
    }

    segments_[segmentIndex] = addr;
    mappingHandles_[segmentIndex] = mappingHandle;
#else
    void *addr = ::mmap(nullptr, segmentSize, PROT_READ | PROT_WRITE,
                        MAP_SHARED, fileDescriptor_, segmentOffset);

    if (addr == MAP_FAILED) {
      logError("mapSegment",
               std::string("Failed to map segment: ") + strerror(errno));
      return false;
    }

    segments_[segmentIndex] = addr;
#endif

    spdlog::debug("Mapped segment {} ({} bytes) for file: {}", segmentIndex,
                  segmentSize, filePath_);
    return true;

  } catch (const std::exception &e) {
    logError("mapSegment", e.what());
    return false;
  }
}

void MemoryMappedCache::unmapAllSegments() {
  for (const auto &[index, addr] : segments_) {
    if (addr) {
#ifdef _WIN32
      UnmapViewOfFile(addr);
      auto handleIt = mappingHandles_.find(index);
      if (handleIt != mappingHandles_.end()) {
        CloseHandle(handleIt->second);
      }
#else
      uint64_t segmentSize =
          std::min(SEGMENT_SIZE, fileSize_ - index * SEGMENT_SIZE);
      munmap(addr, segmentSize);
#endif
    }
  }

  segments_.clear();
#ifdef _WIN32
  mappingHandles_.clear();
#endif
}

void *MemoryMappedCache::getSegmentAddress(uint64_t segmentIndex) {
  auto it = segments_.find(segmentIndex);
  return (it != segments_.end()) ? it->second : nullptr;
}

bool MemoryMappedCache::validateOffset(uint64_t offset, size_t length) const {
  if (offset + length > MAX_CACHE_SIZE) {
    spdlog::error("Operation exceeds maximum cache size");
    return false;
  }
  return true;
}

void MemoryMappedCache::logError(const std::string &operation,
                                 const std::string &error) const {
  spdlog::error("Error in {} operation for file {}: {}", operation, filePath_,
                error);
}

} // namespace audio_stream
