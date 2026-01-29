#ifndef AUDIO_STREAM_WEBSOCKET_MESSAGE_HANDLER_H
#define AUDIO_STREAM_WEBSOCKET_MESSAGE_HANDLER_H

#include "handler/websocket_message.h"
#include "memory/stream_manager.h"
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace audio_stream {

/**
 * Handler for WebSocket messages
 * Processes different message types and coordinates with StreamManager
 */
class WebSocketMessageHandler {
public:
  // Callback type for sending responses
  using SendTextCallback = std::function<void(const std::string &)>;
  using SendBinaryCallback = std::function<void(const std::vector<uint8_t> &)>;

  explicit WebSocketMessageHandler(
      std::shared_ptr<StreamManager> streamManager);
  ~WebSocketMessageHandler() = default;

  // Message handling
  void handleTextMessage(const std::string &message,
                         const std::string &connectionId,
                         SendTextCallback sendText,
                         SendBinaryCallback sendBinary);

  void handleBinaryMessage(const std::vector<uint8_t> &data,
                           const std::string &connectionId,
                           SendTextCallback sendText);

  // Connection management
  void associateStreamWithConnection(const std::string &connectionId,
                                     const std::string &streamId);
  void disassociateConnection(const std::string &connectionId);
  std::string getStreamForConnection(const std::string &connectionId) const;

private:
  void handleStartMessage(const WebSocketMessage &msg,
                          const std::string &connectionId,
                          SendTextCallback sendText);

  void handleStopMessage(const WebSocketMessage &msg,
                         const std::string &connectionId,
                         SendTextCallback sendText);

  void handleGetMessage(const WebSocketMessage &msg, SendTextCallback sendText,
                        SendBinaryCallback sendBinary);

  void sendErrorMessage(const std::string &error, SendTextCallback sendText);

  std::shared_ptr<StreamManager> streamManager_;
  std::map<std::string, std::string>
      connectionStreams_; // connectionId -> streamId
  mutable std::mutex connectionMutex_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_WEBSOCKET_MESSAGE_HANDLER_H
