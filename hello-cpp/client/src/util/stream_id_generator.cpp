#include "util/stream_id_generator.h"
#include <chrono>
#include <iomanip>
#include <random>
#include <sstream>
#include <algorithm>

namespace audio_stream {

StreamIdGenerator::StreamIdGenerator()
    : randomEngine_(
          std::chrono::steady_clock::now().time_since_epoch().count()),
      distribution_(0, 15) {} // 0-15 for hex digits

std::string StreamIdGenerator::generateShort() {
  return generateShortWithPrefix("stream");
}

std::string StreamIdGenerator::generateShortWithPrefix(const std::string& prefix) {
  // Generate 8-character hex string (like Java's UUID.substring(0, 8))
  std::ostringstream oss;
  oss << prefix << "-";

  for (int i = 0; i < 8; ++i) {
    uint32_t randomValue = distribution_(randomEngine_);
    oss << std::hex << std::setw(1) << std::setfill('0') << (randomValue & 0xF);
  }

  std::string streamId = oss.str();
  return streamId;
}

std::string StreamIdGenerator::generateStreamId() {
  // Legacy method: generate stream-{timestamp}-{random}
  auto now = std::chrono::system_clock::now();
  auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                        now.time_since_epoch())
                        .count();

  uint32_t randomValue = distribution_(randomEngine_);

  std::ostringstream oss;
  oss << "stream-" << timestamp << "-" << std::hex << randomValue;
  return oss.str();
}

} // namespace audio_stream
