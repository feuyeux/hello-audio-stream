#ifndef AUDIO_STREAM_STREAM_ID_GENERATOR_H
#define AUDIO_STREAM_STREAM_ID_GENERATOR_H

#include <chrono>
#include <random>
#include <string>

namespace audio_stream {

/**
 * Stream ID generator for creating unique stream identifiers
 * Format: {prefix}-{short-uuid} (matches Java StreamIdGenerator)
 */
class StreamIdGenerator {
public:
  StreamIdGenerator();

  /**
   * Generate a unique stream ID with short UUID
   * @return Unique stream ID in format "stream-{short-uuid}"
   */
  std::string generateShort();

  /**
   * Generate a unique stream ID with custom prefix
   * @param prefix prefix for the stream ID
   * @return Unique stream ID in format "{prefix}-{short-uuid}"
   */
  std::string generateShortWithPrefix(const std::string& prefix);

  /**
   * Generate a unique stream ID (legacy method)
   * @return Unique stream ID in format "stream-{timestamp}-{random}"
   */
  std::string generateStreamId();

private:
  std::mt19937 randomEngine_;
  std::uniform_int_distribution<uint32_t> distribution_;
};

}

#endif // AUDIO_STREAM_STREAM_ID_GENERATOR_H
