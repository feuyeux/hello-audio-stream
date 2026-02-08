#include "handler/websocket_message_handler.h"
#include "../include/common_types.h"
#include "handler/websocket_message.h"
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

using json = nlohmann::json;

namespace audio_stream {

WebSocketMessageHandler::WebSocketMessageHandler(
    std::shared_ptr<StreamManager> streamManager)
    : streamManager_(streamManager) {}

void WebSocketMessageHandler::handleTextMessage(const std::string &message,
                                                const std::string &connectionId,
                                                SendTextCallback sendText,
                                                SendBinaryCallback sendBinary) {
  try {
    spdlog::debug("Received text message: {}", message);

    // Parse JSON message to WebSocketMessage
    WebSocketMessage msg = WebSocketMessage::fromJsonString(message);

    if (msg.type.empty()) {
      sendErrorMessage("Missing 'type' field in message", sendText);
      return;
    }

    MessageType msgType = stringToMessageType(msg.type);

    switch (msgType) {
    case MessageType::START:
      handleStartMessage(msg, connectionId, sendText);
      break;
    case MessageType::STOP:
      handleStopMessage(msg, connectionId, sendText);
      break;
    case MessageType::GET:
      handleGetMessage(msg, sendText, sendBinary);
      break;
    default:
      sendErrorMessage("Unknown message type: " + msg.type, sendText);
      break;
    }
  } catch (const json::parse_error &e) {
    spdlog::error("JSON parse error: {}", e.what());
    sendErrorMessage("Invalid JSON format", sendText);
  } catch (const std::exception &e) {
    spdlog::error("Error handling text message: {}", e.what());
    sendErrorMessage("Internal server error", sendText);
  }
}

void WebSocketMessageHandler::handleBinaryMessage(
    const std::vector<uint8_t> &data, const std::string &connectionId,
    SendTextCallback sendText) {
  try {
    spdlog::debug("Received binary message: {} bytes", data.size());

    // Find the stream associated with this connection
    std::string streamId = getStreamForConnection(connectionId);
    if (streamId.empty()) {
      sendErrorMessage("No active stream for binary data", sendText);
      return;
    }

    // Write the chunk to the stream
    if (streamManager_->writeChunk(streamId, data)) {
      spdlog::debug("Successfully wrote {} bytes to stream {}", data.size(),
                    streamId);
    } else {
      spdlog::error("Failed to write {} bytes to stream {}", data.size(),
                    streamId);
      sendErrorMessage("Failed to write data to stream: " + streamId, sendText);
    }
  } catch (const std::exception &e) {
    spdlog::error("Error handling binary message: {}", e.what());
    sendErrorMessage("Internal error processing binary message", sendText);
  }
}

void WebSocketMessageHandler::handleStartMessage(
    const WebSocketMessage &msg, const std::string &connectionId,
    SendTextCallback sendText) {
  try {
    if (!msg.streamId.has_value() || msg.streamId.value().empty()) {
      sendErrorMessage("Missing 'streamId' field in START message", sendText);
      return;
    }

    std::string streamId = msg.streamId.value();
    spdlog::info("Starting stream: {}", streamId);

    // Create new stream
    if (streamManager_->createStream(streamId)) {
      // Associate this connection with the stream
      associateStreamWithConnection(connectionId, streamId);

      // Send success response using WebSocketMessage
      WebSocketMessage response = WebSocketMessage::started(streamId);
      sendText(response.toJsonString());
      spdlog::info(
          "Stream {} started successfully and associated with connection",
          streamId);
    } else {
      sendErrorMessage("Failed to create stream: " + streamId, sendText);
    }
  } catch (const std::exception &e) {
    spdlog::error("Error handling START message: {}", e.what());
    sendErrorMessage("Internal error processing START message", sendText);
  }
}

void WebSocketMessageHandler::handleStopMessage(const WebSocketMessage &msg,
                                                const std::string &connectionId,
                                                SendTextCallback sendText) {
  try {
    if (!msg.streamId.has_value() || msg.streamId.value().empty()) {
      sendErrorMessage("Missing 'streamId' field in STOP message", sendText);
      return;
    }

    std::string streamId = msg.streamId.value();
    spdlog::info("Stopping stream: {}", streamId);

    // Disassociate connection from stream
    disassociateConnection(connectionId);

    // Send success response using WebSocketMessage
    WebSocketMessage response = WebSocketMessage::stopped(streamId);
    sendText(response.toJsonString());
    spdlog::info(
        "Stream {} stopped successfully and disconnected from connection",
        streamId);
  } catch (const std::exception &e) {
    spdlog::error("Error handling STOP message: {}", e.what());
    sendErrorMessage("Internal error processing STOP message", sendText);
  }
}

void WebSocketMessageHandler::handleGetMessage(const WebSocketMessage &msg,
                                               SendTextCallback sendText,
                                               SendBinaryCallback sendBinary) {
  try {
    if (!msg.streamId.has_value() || !msg.offset.has_value() ||
        !msg.length.has_value()) {
      sendErrorMessage(
          "Missing required fields in GET message (streamId, offset, length)",
          sendText);
      return;
    }

    std::string streamId = msg.streamId.value();
    size_t offset = msg.offset.value();
    size_t length = msg.length.value();

    spdlog::debug("Getting data from stream: {} offset: {} length: {}",
                  streamId, offset, length);

    // Read data from stream
    std::vector<uint8_t> data =
        streamManager_->readChunk(streamId, offset, length);

    if (!data.empty()) {
      // Send binary data
      sendBinary(data);
      spdlog::debug("Sent {} bytes from stream {}", data.size(), streamId);
    } else {
      // Check if this is end of file or an actual error
      auto stream = streamManager_->getStream(streamId);
      if (stream && offset >= stream->totalSize) {
        // End of file
        sendErrorMessage("No data available", sendText);
        spdlog::debug("End of file reached for stream {} at offset {}",
                      streamId, offset);
      } else {
        // Actual error
        sendErrorMessage("Failed to read from stream: " + streamId, sendText);
      }
    }
  } catch (const json::parse_error &e) {
    spdlog::error("JSON parse error in GET message: {}", e.what());
    sendErrorMessage("Invalid JSON in GET message", sendText);
  } catch (const std::exception &e) {
    spdlog::error("Error handling GET message: {}", e.what());
    sendErrorMessage("Internal error processing GET message", sendText);
  }
}

void WebSocketMessageHandler::sendErrorMessage(const std::string &error,
                                               SendTextCallback sendText) {
  try {
    WebSocketMessage errorMsg = WebSocketMessage::error(error);
    sendText(errorMsg.toJsonString());
    spdlog::debug("Sent error message: {}", error);
  } catch (const std::exception &e) {
    spdlog::error("Error sending error message: {}", e.what());
  }
}

void WebSocketMessageHandler::associateStreamWithConnection(
    const std::string &connectionId, const std::string &streamId) {
  std::lock_guard<std::mutex> lock(connectionMutex_);
  connectionStreams_[connectionId] = streamId;
}

void WebSocketMessageHandler::disassociateConnection(
    const std::string &connectionId) {
  std::lock_guard<std::mutex> lock(connectionMutex_);
  connectionStreams_.erase(connectionId);
}

std::string WebSocketMessageHandler::getStreamForConnection(
    const std::string &connectionId) const {
  std::lock_guard<std::mutex> lock(connectionMutex_);
  auto it = connectionStreams_.find(connectionId);
  if (it != connectionStreams_.end()) {
    return it->second;
  }
  return "";
}

} // namespace audio_stream
