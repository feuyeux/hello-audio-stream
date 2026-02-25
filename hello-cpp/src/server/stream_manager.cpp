#include "server/stream_manager.h"
#include <algorithm>
#include <iostream>

namespace audio_stream
{

    StreamManager::StreamManager(const StreamManagerConfig &cfg) : cfg_(cfg)
    {
        std::filesystem::create_directories(cfg_.cacheDir);
        std::cout << "[StreamManager] cache=" << cfg_.cacheDir
                  << " maxStreams=" << cfg_.maxStreams << "\n";
    }

    StreamManager::~StreamManager()
    {
        std::lock_guard<std::mutex> lk(mu_);
        streams_.clear();
    }

    bool StreamManager::create(const std::string &streamId)
    {
        std::lock_guard<std::mutex> lk(mu_);
        if (streams_.count(streamId))
        {
            std::cerr << "[StreamManager] Stream already exists: " << streamId << "\n";
            return false;
        }
        if (static_cast<int>(streams_.size()) >= cfg_.maxStreams)
        {
            std::cerr << "[StreamManager] Max streams reached (" << cfg_.maxStreams << ")\n";
            return false;
        }
        auto s = std::make_shared<Stream>(streamId, cachePath(streamId));
        streams_[streamId] = s;
        std::cout << "[StreamManager] Created stream: " << streamId << "\n";
        return true;
    }

    bool StreamManager::write(const std::string &streamId, const std::vector<uint8_t> &data)
    {
        std::shared_ptr<Stream> s;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = streams_.find(streamId);
            if (it == streams_.end())
                return false;
            s = it->second;
        }

        std::lock_guard<std::mutex> sl(s->mu);
        if (s->status != StreamStatus::UPLOADING)
            return false;

        size_t written = s->cache->write(data);
        if (written != data.size())
            return false;
        s->totalSize += written;
        s->lastAccessedAt = std::chrono::system_clock::now();
        return true;
    }

    bool StreamManager::complete(const std::string &streamId)
    {
        std::shared_ptr<Stream> s;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = streams_.find(streamId);
            if (it == streams_.end())
                return false;
            s = it->second;
        }

        std::lock_guard<std::mutex> sl(s->mu);
        if (s->status != StreamStatus::UPLOADING)
            return false;

        if (!s->cache->finalize(s->totalSize))
            return false;
        s->status = StreamStatus::READY;
        s->lastAccessedAt = std::chrono::system_clock::now();
        std::cout << "[StreamManager] Completed stream: " << streamId
                  << " size=" << s->totalSize << "\n";
        return true;
    }

    std::vector<uint8_t> StreamManager::read(const std::string &streamId, uint64_t offset, size_t length)
    {
        std::shared_ptr<Stream> s;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = streams_.find(streamId);
            if (it == streams_.end())
                return {};
            s = it->second;
        }

        std::lock_guard<std::mutex> sl(s->mu);
        s->lastAccessedAt = std::chrono::system_clock::now();
        return s->cache->read(offset, length);
    }

    bool StreamManager::remove(const std::string &streamId)
    {
        std::lock_guard<std::mutex> lk(mu_);
        auto it = streams_.find(streamId);
        if (it == streams_.end())
            return false;

        it->second->cache->close();
        try
        {
            std::filesystem::remove(cachePath(streamId));
        }
        catch (...)
        {
        }
        streams_.erase(it);
        std::cout << "[StreamManager] Removed stream: " << streamId << "\n";
        return true;
    }

    void StreamManager::markError(const std::string &streamId)
    {
        std::shared_ptr<Stream> s;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = streams_.find(streamId);
            if (it == streams_.end())
                return;
            s = it->second;
        }

        std::lock_guard<std::mutex> sl(s->mu);
        if (s->status == StreamStatus::UPLOADING)
        {
            s->status = StreamStatus::ERROR;
            std::cout << "[StreamManager] Marked ERROR: " << streamId << "\n";
        }
    }

    std::pair<std::string, int64_t> StreamManager::statusOf(const std::string &streamId)
    {
        std::shared_ptr<Stream> s;
        {
            std::lock_guard<std::mutex> lk(mu_);
            auto it = streams_.find(streamId);
            if (it == streams_.end())
                return {"", -1};
            s = it->second;
        }

        std::lock_guard<std::mutex> sl(s->mu);
        s->lastAccessedAt = std::chrono::system_clock::now();
        return {statusToString(s->status), static_cast<int64_t>(s->totalSize)};
    }

    std::string StreamManager::list()
    {
        std::lock_guard<std::mutex> lk(mu_);
        std::ostringstream oss;
        bool first = true;
        for (auto &[id, _] : streams_)
        {
            if (!first)
                oss << ",";
            oss << id;
            first = false;
        }
        return oss.str();
    }

    void StreamManager::cleanup()
    {
        std::lock_guard<std::mutex> lk(mu_);
        auto now = std::chrono::system_clock::now();

        auto it = streams_.begin();
        while (it != streams_.end())
        {
            auto &s = it->second;
            std::lock_guard<std::mutex> sl(s->mu);

            auto idleHours = std::chrono::duration_cast<std::chrono::hours>(now - s->lastAccessedAt).count();
            auto ageHours = std::chrono::duration_cast<std::chrono::hours>(now - s->createdAt).count();

            bool expired = false;
            if (s->status == StreamStatus::UPLOADING && ageHours >= cfg_.maxUploadingHours)
                expired = true;
            if (s->status == StreamStatus::ERROR && ageHours >= cfg_.maxUploadingHours)
                expired = true;
            if (idleHours >= cfg_.maxIdleHours)
                expired = true;

            if (expired)
            {
                std::cout << "[StreamManager] Cleanup expired stream: " << it->first << "\n";
                s->cache->close();
                try
                {
                    std::filesystem::remove(cachePath(it->first));
                }
                catch (...)
                {
                }
                it = streams_.erase(it);
            }
            else
            {
                ++it;
            }
        }
    }

    size_t StreamManager::count() const
    {
        std::lock_guard<std::mutex> lk(mu_);
        return streams_.size();
    }

    std::string StreamManager::cachePath(const std::string &streamId) const
    {
        return cfg_.cacheDir + "/" + streamId + ".cache";
    }

} // namespace audio_stream
