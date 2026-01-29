#ifndef AUDIO_STREAM_WEBSOCKET_MESSAGE_H
#define AUDIO_STREAM_WEBSOCKET_MESSAGE_H

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

namespace audio_stream {

/**
 * WebSocket control message for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */
struct WebSocketMessage {
  std::string type;
  std::optional<std::string> streamId;
  std::optional<size_t> offset;
  std::optional<size_t> length;
  std::optional<std::string> message;

  // Default constructor
  WebSocketMessage() = default;

  // Constructor with all fields
  WebSocketMessage(const std::string &type,
                   const std::optional<std::string> &streamId = std::nullopt,
                   const std::optional<size_t> &offset = std::nullopt,
                   const std::optional<size_t> &length = std::nullopt,
                   const std::optional<std::string> &message = std::nullopt)
      : type(type), streamId(streamId), offset(offset), length(length),
        message(message) {}

  // Factory methods for common message types
  static WebSocketMessage
  started(const std::string &streamId,
          const std::string &msg = "Stream started successfully") {
    return WebSocketMessage("STARTED", streamId, std::nullopt, std::nullopt,
                            msg);
  }

  static WebSocketMessage
  stopped(const std::string &streamId,
          const std::string &msg = "Stream stopped successfully") {
    return WebSocketMessage("STOPPED", streamId, std::nullopt, std::nullopt,
                            msg);
  }

  static WebSocketMessage error(const std::string &msg) {
    return WebSocketMessage("ERROR", std::nullopt, std::nullopt, std::nullopt,
                            msg);
  }

  // Convert to JSON
  nlohmann::json toJson() const {
    nlohmann::json j;
    j["type"] = type;
    if (streamId.has_value())
      j["streamId"] = streamId.value();
    if (offset.has_value())
      j["offset"] = offset.value();
    if (length.has_value())
      j["length"] = length.value();
    if (message.has_value())
      j["message"] = message.value();
    return j;
  }

  // Convert to JSON string
  std::string toJsonString() const { return toJson().dump(); }

  // Parse from JSON
  static WebSocketMessage fromJson(const nlohmann::json &j) {
    WebSocketMessage msg;
    msg.type = j.value("type", "");
    if (j.contains("streamId"))
      msg.streamId = j["streamId"].get<std::string>();
    if (j.contains("offset"))
      msg.offset = j["offset"].get<size_t>();
    if (j.contains("length"))
      msg.length = j["length"].get<size_t>();
    if (j.contains("message"))
      msg.message = j["message"].get<std::string>();
    return msg;
  }

  // Parse from JSON string
  static WebSocketMessage fromJsonString(const std::string &jsonStr) {
    nlohmann::json j = nlohmann::json::parse(jsonStr);
    return fromJson(j);
  }
};

} // namespace audio_stream

#endif // AUDIO_STREAM_WEBSOCKET_MESSAGE_H
