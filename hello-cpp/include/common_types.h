#ifndef AUDIO_STREAM_COMMON_TYPES_H
#define AUDIO_STREAM_COMMON_TYPES_H

#include <chrono>
#include <cstdint>
#include <nlohmann/json.hpp>
#include <string>

namespace audio_stream {

// Constants
constexpr size_t CHUNK_SIZE = 65536; // 64KB
constexpr int DEFAULT_PORT = 8080;
constexpr int DEFAULT_TIMEOUT_MS = 5000;
constexpr int DEFAULT_MAX_RETRIES = 10;

// String constants
#define DEFAULT_PATH "/audio"

// Message types
enum class MessageType { START, STARTED, STOP, STOPPED, GET, ERROR_MSG };

// Convert MessageType to uppercase string
inline std::string messageTypeToString(MessageType type) {
  switch (type) {
  case MessageType::START:
    return "START";
  case MessageType::STARTED:
    return "STARTED";
  case MessageType::STOP:
    return "STOP";
  case MessageType::STOPPED:
    return "STOPPED";
  case MessageType::GET:
    return "GET";
  case MessageType::ERROR_MSG:
    return "ERROR";
  default:
    return "UNKNOWN";
  }
}

// Parse string to MessageType
inline MessageType stringToMessageType(const std::string &typeStr) {
  if (typeStr == "START")
    return MessageType::START;
  if (typeStr == "STARTED")
    return MessageType::STARTED;
  if (typeStr == "STOP")
    return MessageType::STOP;
  if (typeStr == "STOPPED")
    return MessageType::STOPPED;
  if (typeStr == "GET")
    return MessageType::GET;
  if (typeStr == "ERROR")
    return MessageType::ERROR_MSG;
  return MessageType::ERROR_MSG; // Default to error for unknown types
}

// Control message structures
struct StartMessage {
  std::string type = "START";
  std::string streamId;
};

struct StartedMessage {
  std::string type = "STARTED";
  std::string message;
  std::string streamId;
};

struct StopMessage {
  std::string type = "STOP";
  std::string streamId;
};

struct StoppedMessage {
  std::string type = "STOPPED";
  std::string message;
  std::string streamId;
};

struct GetMessage {
  std::string type = "GET";
  std::string streamId;
  size_t offset;
  size_t length;

  // Constructor
  GetMessage(const std::string &id, int64_t off, int64_t len)
      : streamId(id), offset(static_cast<size_t>(off)),
        length(static_cast<size_t>(len)) {}

  // Default constructor
  GetMessage() = default;

  // Serialize to JSON
  std::string toJson() const {
    nlohmann::json j;
    j["type"] = type;
    j["streamId"] = streamId;
    j["offset"] = offset;
    j["length"] = length;
    return j.dump();
  }
};

struct ErrorMessage {
  std::string type = "ERROR";
  std::string message;
};

// Stream status
enum class StreamStatus { UPLOADING, READY, DOWNLOADING };

// Performance metrics
struct PerformanceMetrics {
  std::chrono::steady_clock::time_point uploadStartTime;
  std::chrono::steady_clock::time_point uploadEndTime;
  size_t uploadBytes = 0;
  double uploadThroughputMbps = 0.0;

  std::chrono::steady_clock::time_point downloadStartTime;
  std::chrono::steady_clock::time_point downloadEndTime;
  size_t downloadBytes = 0;
  double downloadThroughputMbps = 0.0;
};

// Verification report
struct VerificationReport {
  std::string originalFilePath;
  std::string downloadedFilePath;
  size_t originalSize = 0;
  size_t downloadedSize = 0;
  std::string originalChecksum;
  std::string downloadedChecksum;
  bool sizesMatch = false;
  bool checksumsMatch = false;
  bool verificationPassed = false;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_COMMON_TYPES_H
