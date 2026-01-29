#ifndef AUDIO_STREAM_WEBSOCKET_SERVER_H
#define AUDIO_STREAM_WEBSOCKET_SERVER_H

// Windows-specific: prevent winsock.h/winsock2.h conflicts
#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winsock2.h>
#endif

#include "../include/common_types.h"
#include "handler/websocket_message_handler.h"
#include "memory/stream_manager.h"
#include <map>
#include <memory>
#include <mutex>
#include <spdlog/spdlog.h>
#include <string>
#include <thread>

// Third-party library websocketpp has pointer arithmetic warning in md5.hpp
// This is a known issue in the library and cannot be fixed without modifying
// third-party code Issue: https://github.com/zaphoyd/websocketpp/issues/1006
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnull-pointer-subtraction"
#include <websocketpp/config/asio_no_tls.hpp>
#include <websocketpp/server.hpp>
#pragma GCC diagnostic pop

namespace audio_stream {

using WebSocketServer_t = websocketpp::server<websocketpp::config::asio>;
using ConnectionHdl = websocketpp::connection_hdl;

/**
 * WebSocket server for audio stream cache system
 * Accepts connections and routes messages to appropriate handlers
 */
class WebSocketServer {
public:
  WebSocketServer(int port, const std::string &path);
  ~WebSocketServer();

  // Server lifecycle
  void start();
  void stop();
  bool isRunning() const;

private:
  void initializeServer();
  void onOpen(ConnectionHdl hdl);
  void onClose(ConnectionHdl hdl);
  void onFail(ConnectionHdl hdl);
  template <typename MsgType>
  void onMessage(ConnectionHdl hdl, const MsgType &msg) {
    try {
      if (msg->get_opcode() == websocketpp::frame::opcode::text) {
        std::string payload = msg->get_payload();
        spdlog::debug("Text message received: {}", payload);
        handleTextMessage(hdl, payload);
      } else if (msg->get_opcode() == websocketpp::frame::opcode::binary) {
        std::string payload = msg->get_payload();
        std::vector<uint8_t> data(payload.begin(), payload.end());
        handleBinaryMessage(hdl, data);
      }
    } catch (const std::exception &e) {
      spdlog::error("Error handling message: {}", e.what());
      sendErrorMessage(hdl, std::string("Message handling error: ") + e.what());
    }
  }

  // Message handlers - delegate to message handler
  void handleTextMessage(ConnectionHdl hdl, const std::string &message);
  void handleBinaryMessage(ConnectionHdl hdl, const std::vector<uint8_t> &data);

  // Response helpers
  void sendTextMessage(ConnectionHdl hdl, const std::string &message);
  void sendBinaryMessage(ConnectionHdl hdl, const std::vector<uint8_t> &data);
  void sendErrorMessage(ConnectionHdl hdl, const std::string &error);

  // Helper to get connection ID
  std::string getConnectionId(ConnectionHdl hdl) const;

  int port_;
  std::string path_;
  bool running_;
  WebSocketServer_t server_;
  std::shared_ptr<StreamManager> streamManager_;
  std::unique_ptr<WebSocketMessageHandler> messageHandler_;
  std::thread serverThread_;

  // Connection to remote endpoint mapping (for logging)
  std::map<ConnectionHdl, std::string, std::owner_less<ConnectionHdl>>
      connectionEndpoints_;
  mutable std::mutex connectionMutex_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_WEBSOCKET_SERVER_H
