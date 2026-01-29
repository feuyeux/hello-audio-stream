#ifndef AUDIO_STREAM_STREAM_ID_GENERATOR_H
#define AUDIO_STREAM_STREAM_ID_GENERATOR_H

#include <chrono>
#include <random>
#include <string>

namespace audio_stream {

/**
 * Stream ID generator for creating unique stream identifiers
 * Format: stream-{timestamp}-{random}
 */
class StreamIdGenerator {
public:
  StreamIdGenerator();

  /**
   * Generate a unique stream ID
   * @return Unique stream ID in format "stream-{timestamp}-{random}"
   */
  std::string generateStreamId();

private:
  std::mt19937 randomEngine_;
  std::uniform_int_distribution<uint32_t> distribution_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_STREAM_ID_GENERATOR_H