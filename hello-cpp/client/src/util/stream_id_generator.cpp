#include "util/stream_id_generator.h"
#include <iomanip>
#include <sstream>

namespace audio_stream {

StreamIdGenerator::StreamIdGenerator()
    : randomEngine_(
          std::chrono::steady_clock::now().time_since_epoch().count()),
      distribution_(0, UINT32_MAX) {}

std::string StreamIdGenerator::generateStreamId() {
  // Get current timestamp in milliseconds
  auto now = std::chrono::system_clock::now();
  auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                       now.time_since_epoch())
                       .count();

  // Generate random number
  uint32_t randomValue = distribution_(randomEngine_);

  // Format: stream-{timestamp}-{random}
  std::ostringstream oss;
  oss << "stream-" << timestamp << "-" << std::hex << randomValue;

  return oss.str();
}

} // namespace audio_stream