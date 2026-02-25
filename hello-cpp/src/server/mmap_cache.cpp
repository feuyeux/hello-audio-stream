#include "server/mmap_cache.h"
#include <algorithm>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>

#ifdef _WIN32
// windows.h already included via header
#else
#include <errno.h>
#include <sys/stat.h>
#endif

namespace audio_stream
{

    MmapCache::MmapCache(const std::string &filePath) : filePath_(filePath) {}

    MmapCache::~MmapCache() { close(); }

    // ── helpers ─────────────────────────────────────────────────────────

    bool MmapCache::ensureOpen()
    {
        if (opened_)
            return true;

        // Create or truncate the file
        {
            std::ofstream f(filePath_, std::ios::binary | std::ios::trunc);
            if (!f)
            {
                std::cerr << "[MmapCache] Cannot create file: " << filePath_ << "\n";
                return false;
            }
        }

        fileSize_ = 0;
        writeOffset_ = 0;

#ifdef _WIN32
        fileHandle_ = CreateFileA(filePath_.c_str(),
                                  GENERIC_READ | GENERIC_WRITE,
                                  FILE_SHARE_READ | FILE_SHARE_WRITE,
                                  nullptr, OPEN_EXISTING,
                                  FILE_ATTRIBUTE_NORMAL, nullptr);
        if (fileHandle_ == INVALID_HANDLE_VALUE)
        {
            std::cerr << "[MmapCache] CreateFileA failed: " << filePath_ << "\n";
            return false;
        }
#else
        fd_ = ::open(filePath_.c_str(), O_RDWR);
        if (fd_ == -1)
        {
            std::cerr << "[MmapCache] open() failed: " << filePath_
                      << " (" << strerror(errno) << ")\n";
            return false;
        }
#endif

        opened_ = true;
        return true;
    }

    bool MmapCache::ensureCapacity(uint64_t needed)
    {
        if (needed <= mappedSize_)
            return true;

        // Grow in GROW_STEP increments
        uint64_t newSize = ((needed + GROW_STEP - 1) / GROW_STEP) * GROW_STEP;

        unmapRegion();

        // Resize the underlying file
        try
        {
            std::filesystem::resize_file(filePath_, newSize);
        }
        catch (const std::exception &e)
        {
            std::cerr << "[MmapCache] resize_file failed: " << e.what() << "\n";
            return false;
        }

        fileSize_ = newSize;
        mapRegion();
        return mappedAddr_ != nullptr;
    }

    void MmapCache::mapRegion()
    {
        if (fileSize_ == 0)
            return;

#ifdef _WIN32
        mappingHandle_ = CreateFileMappingA(
            fileHandle_, nullptr, PAGE_READWRITE,
            static_cast<DWORD>(fileSize_ >> 32),
            static_cast<DWORD>(fileSize_ & 0xFFFFFFFF), nullptr);
        if (!mappingHandle_)
        {
            std::cerr << "[MmapCache] CreateFileMappingA failed\n";
            return;
        }
        mappedAddr_ = MapViewOfFile(mappingHandle_, FILE_MAP_ALL_ACCESS, 0, 0, 0);
        if (!mappedAddr_)
        {
            CloseHandle(mappingHandle_);
            mappingHandle_ = nullptr;
            std::cerr << "[MmapCache] MapViewOfFile failed\n";
            return;
        }
#else
        mappedAddr_ = ::mmap(nullptr, fileSize_, PROT_READ | PROT_WRITE,
                             MAP_SHARED, fd_, 0);
        if (mappedAddr_ == MAP_FAILED)
        {
            mappedAddr_ = nullptr;
            std::cerr << "[MmapCache] mmap failed: " << strerror(errno) << "\n";
            return;
        }
#endif
        mappedSize_ = fileSize_;
    }

    void MmapCache::unmapRegion()
    {
        if (!mappedAddr_)
            return;

#ifdef _WIN32
        FlushViewOfFile(mappedAddr_, 0);
        UnmapViewOfFile(mappedAddr_);
        if (mappingHandle_)
        {
            CloseHandle(mappingHandle_);
            mappingHandle_ = nullptr;
        }
#else
        msync(mappedAddr_, mappedSize_, MS_SYNC);
        munmap(mappedAddr_, mappedSize_);
#endif
        mappedAddr_ = nullptr;
        mappedSize_ = 0;
    }

    // ── public API ──────────────────────────────────────────────────────

    size_t MmapCache::write(const std::vector<uint8_t> &data)
    {
        if (data.empty())
            return 0;

        if (!ensureOpen())
            return 0;
        if (!ensureCapacity(writeOffset_ + data.size()))
            return 0;

        auto *dst = static_cast<uint8_t *>(mappedAddr_) + writeOffset_;
        std::memcpy(dst, data.data(), data.size());

#ifdef _WIN32
        FlushViewOfFile(dst, data.size());
#else
        msync(dst, data.size(), MS_ASYNC);
#endif

        writeOffset_ += data.size();
        return data.size();
    }

    std::vector<uint8_t> MmapCache::read(uint64_t offset, size_t length)
    {
        if (!opened_)
        {
            // Try opening an existing file for reading
            if (!std::filesystem::exists(filePath_))
                return {};
            fileSize_ = std::filesystem::file_size(filePath_);
            if (fileSize_ == 0)
                return {};

#ifdef _WIN32
            fileHandle_ = CreateFileA(filePath_.c_str(),
                                      GENERIC_READ | GENERIC_WRITE,
                                      FILE_SHARE_READ | FILE_SHARE_WRITE,
                                      nullptr, OPEN_EXISTING,
                                      FILE_ATTRIBUTE_NORMAL, nullptr);
            if (fileHandle_ == INVALID_HANDLE_VALUE)
                return {};
#else
            fd_ = ::open(filePath_.c_str(), O_RDWR);
            if (fd_ == -1)
                return {};
#endif
            opened_ = true;
            mapRegion();
            if (!mappedAddr_)
                return {};
        }

        if (!mappedAddr_ && fileSize_ > 0)
        {
            mapRegion();
            if (!mappedAddr_)
                return {};
        }

        // Bounds check
        uint64_t actualEnd = std::min(offset + length, writeOffset_ > 0 ? writeOffset_ : fileSize_);
        if (offset >= actualEnd)
            return {};
        size_t actualLen = static_cast<size_t>(actualEnd - offset);

        const auto *src = static_cast<const uint8_t *>(mappedAddr_) + offset;
        return {src, src + actualLen};
    }

    bool MmapCache::finalize(uint64_t finalSize)
    {
        if (!opened_)
            return false;

        unmapRegion();

        try
        {
            std::filesystem::resize_file(filePath_, finalSize);
        }
        catch (...)
        {
            return false;
        }

        fileSize_ = finalSize;
        writeOffset_ = finalSize;
        mapRegion();

#ifdef _WIN32
        if (mappedAddr_)
            FlushViewOfFile(mappedAddr_, 0);
#else
        if (mappedAddr_)
            msync(mappedAddr_, fileSize_, MS_SYNC);
#endif
        return true;
    }

    void MmapCache::close()
    {
        unmapRegion();
#ifdef _WIN32
        if (fileHandle_ != INVALID_HANDLE_VALUE)
        {
            CloseHandle(fileHandle_);
            fileHandle_ = INVALID_HANDLE_VALUE;
        }
#else
        if (fd_ >= 0)
        {
            ::close(fd_);
            fd_ = -1;
        }
#endif
        opened_ = false;
    }

} // namespace audio_stream
