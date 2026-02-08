#ifndef AUDIO_STREAM_STREAM_MANAGER_H
#define AUDIO_STREAM_STREAM_MANAGER_H

#include "stream_context.h"
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace audio_stream {

/**
 * Stream manager for managing active audio streams
 * Thread-safe registry of stream contexts
 */
class StreamManager {
public:
  StreamManager(const std::string &cacheDir);
  ~StreamManager();

  // Stream lifecycle
  bool createStream(const std::string &streamId);
  std::shared_ptr<StreamContext> getStream(const std::string &streamId);
  bool deleteStream(const std::string &streamId);
  std::vector<std::string> listActiveStreams();

  // Stream operations
  bool writeChunk(const std::string &streamId,
                  const std::vector<uint8_t> &data);
  std::vector<uint8_t> readChunk(const std::string &streamId, size_t offset,
                                 size_t length);
  bool finalizeStream(const std::string &streamId);

  // Utility
  void cleanupOldStreams();

private:
  std::string getCachePath(const std::string &streamId) const;

  std::string cacheDir_;
  std::map<std::string, std::shared_ptr<StreamContext>> streams_;
  mutable std::mutex mutex_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_STREAM_MANAGER_H
