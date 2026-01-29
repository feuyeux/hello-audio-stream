#ifndef AUDIO_STREAM_WEBSOCKET_CLIENT_H
#define AUDIO_STREAM_WEBSOCKET_CLIENT_H

#include "../../include/common_types.h"
#include <functional>
#include <memory>
#include <string>
#include <vector>

// spdlog header for logging in template member functions
#include <spdlog/spdlog.h>

// Define ASIO_STANDALONE before including websocketpp
#ifndef ASIO_STANDALONE
#define ASIO_STANDALONE
#endif

// Third-party library websocketpp has pointer arithmetic warning in md5.hpp
// This is a known issue in the library and cannot be fixed without modifying
// third-party code Issue: https://github.com/zaphoyd/websocketpp/issues/1006
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnull-pointer-subtraction"
#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_no_tls.hpp>
#pragma GCC diagnostic pop

namespace audio_stream {

using WebSocketClient_t = websocketpp::client<websocketpp::config::asio>;
using ConnectionHdl = websocketpp::connection_hdl;

/**
 * WebSocket client for audio stream communication
 * Handles connection, message sending/receiving, and reconnection logic
 */
class WebSocketClient {
public:
  explicit WebSocketClient(const std::string &uri);
  virtual ~WebSocketClient();

  // Connection management
  virtual bool connect();
  virtual bool connectWithRetry(int maxRetries = DEFAULT_MAX_RETRIES);
  virtual void disconnect();
  virtual bool isConnected() const;

  // Message sending
  virtual void sendTextMessage(const std::string &message);
  virtual void sendBinaryMessage(const std::vector<uint8_t> &data);

  // Message handlers
  virtual void setOnMessage(std::function<void(const std::string &)> handler);
  virtual void
  setOnBinaryMessage(std::function<void(const std::vector<uint8_t> &)> handler);
  virtual void setOnError(std::function<void(const std::string &)> handler);

private:
  void onOpen(ConnectionHdl hdl);
  void onClose(ConnectionHdl hdl);
  void onFail(ConnectionHdl hdl);
  bool attemptConnection();
  void waitWithExponentialBackoff(int attempt);

  template <typename MsgType>
  void onMessage([[maybe_unused]] ConnectionHdl hdl, const MsgType &msg) {
    if (msg->get_opcode() == websocketpp::frame::opcode::text) {
      std::string payload = msg->get_payload();
      spdlog::debug("Text message received: {}", payload);
      if (onMessageHandler_) {
        onMessageHandler_(payload);
      }
    } else if (msg->get_opcode() == websocketpp::frame::opcode::binary) {
      std::string payload = msg->get_payload();
      std::vector<uint8_t> data(payload.begin(), payload.end());
      spdlog::debug("Binary message received: {} bytes", data.size());
      if (onBinaryMessageHandler_) {
        onBinaryMessageHandler_(data);
      }
    }
  }

  std::string uri_;
  bool connected_;
  WebSocketClient_t client_;
  ConnectionHdl connection_;

  std::function<void(const std::string &)> onMessageHandler_;
  std::function<void(const std::vector<uint8_t> &)> onBinaryMessageHandler_;
  std::function<void(const std::string &)> onErrorHandler_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_WEBSOCKET_CLIENT_H
