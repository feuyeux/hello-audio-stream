#ifndef AUDIO_STREAM_STREAM_MANAGER_H
#define AUDIO_STREAM_STREAM_MANAGER_H

#include "mmap_cache.h"
#include "protocol.h"
#include <chrono>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace audio_stream
{

    enum class StreamStatus
    {
        UPLOADING,
        READY,
        ERROR
    };

    inline std::string statusToString(StreamStatus s)
    {
        switch (s)
        {
        case StreamStatus::UPLOADING:
            return "UPLOADING";
        case StreamStatus::READY:
            return "READY";
        case StreamStatus::ERROR:
            return "ERROR";
        }
        return "UNKNOWN";
    }

    struct Stream
    {
        std::string id;
        StreamStatus status = StreamStatus::UPLOADING;
        std::unique_ptr<MmapCache> cache;
        std::chrono::system_clock::time_point createdAt;
        std::chrono::system_clock::time_point lastAccessedAt;
        uint64_t totalSize = 0;
        mutable std::mutex mu;

        explicit Stream(const std::string &id, const std::string &cachePath)
            : id(id),
              cache(std::make_unique<MmapCache>(cachePath)),
              createdAt(std::chrono::system_clock::now()),
              lastAccessedAt(createdAt) {}
    };

    struct StreamManagerConfig
    {
        std::string cacheDir = "cache";
        int maxIdleHours = 24;
        int maxUploadingHours = 1;
        int maxStreams = 1000;
    };

    class StreamManager
    {
    public:
        explicit StreamManager(const StreamManagerConfig &cfg);
        ~StreamManager();

        /// Create a new stream. Returns false if already exists or at capacity.
        bool create(const std::string &streamId);

        /// Write binary data to a stream.
        bool write(const std::string &streamId, const std::vector<uint8_t> &data);

        /// Mark upload complete – finalize cache.
        bool complete(const std::string &streamId);

        /// Read from a READY/UPLOADING stream.
        std::vector<uint8_t> read(const std::string &streamId, uint64_t offset, size_t length);

        /// Delete (close) a stream.
        bool remove(const std::string &streamId);

        /// Mark a stream as ERROR.
        void markError(const std::string &streamId);

        /// Return status string + size for a stream, or empty if not found.
        std::pair<std::string, int64_t> statusOf(const std::string &streamId);

        /// List all stream IDs as a comma-separated string.
        std::string list();

        /// Cleanup expired streams.
        void cleanup();

        /// Stats: current stream count.
        size_t count() const;

    private:
        std::string cachePath(const std::string &streamId) const;

        StreamManagerConfig cfg_;
        std::map<std::string, std::shared_ptr<Stream>> streams_;
        mutable std::mutex mu_;
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_STREAM_MANAGER_H
