#ifndef AUDIO_STREAM_MMAP_CACHE_H
#define AUDIO_STREAM_MMAP_CACHE_H

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#ifdef ERROR
#undef ERROR // Windows macro conflicts with our enum values
#endif
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#endif

namespace audio_stream
{

    /// File-backed memory-mapped cache. Cross-platform (Win32 + POSIX).
    class MmapCache
    {
    public:
        explicit MmapCache(const std::string &filePath);
        ~MmapCache();

        MmapCache(const MmapCache &) = delete;
        MmapCache &operator=(const MmapCache &) = delete;

        /// Append data at the current write offset. Returns bytes written.
        size_t write(const std::vector<uint8_t> &data);

        /// Read `length` bytes starting at `offset`.
        std::vector<uint8_t> read(uint64_t offset, size_t length);

        /// Truncate file to finalSize and flush.
        bool finalize(uint64_t finalSize);

        void close();

        uint64_t size() const { return fileSize_; }
        const std::string &filePath() const { return filePath_; }

    private:
        bool ensureOpen();
        bool ensureCapacity(uint64_t needed);
        void mapRegion();
        void unmapRegion();

        std::string filePath_;
        uint64_t fileSize_ = 0;
        uint64_t mappedSize_ = 0;
        uint64_t writeOffset_ = 0;
        void *mappedAddr_ = nullptr;
        bool opened_ = false;

        static constexpr uint64_t GROW_STEP = 4ULL * 1024 * 1024; // 4 MB

#ifdef _WIN32
        HANDLE fileHandle_ = INVALID_HANDLE_VALUE;
        HANDLE mappingHandle_ = nullptr;
#else
        int fd_ = -1;
#endif
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_MMAP_CACHE_H
