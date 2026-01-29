#include "network/audio_websocket_server.h"
#include "handler/websocket_message_handler.h"
#include <filesystem>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

using json = nlohmann::json;

namespace audio_stream {

WebSocketServer::WebSocketServer(int port, const std::string &path)
    : port_(port), path_(path), running_(false) {
  initializeServer();

  // Create cache directory
  std::string cacheDir = "cache";
  std::filesystem::create_directories(cacheDir);

  // Initialize stream manager
  streamManager_ = std::make_shared<StreamManager>(cacheDir);

  // Initialize message handler
  messageHandler_ = std::make_unique<WebSocketMessageHandler>(streamManager_);

  spdlog::info("WebSocketServer created on port {} with path {}", port, path);
}

WebSocketServer::~WebSocketServer() { stop(); }

void WebSocketServer::initializeServer() {
  try {
    // Set logging settings - disable websocketpp's internal logging to avoid
    // localized error messages
    server_.clear_access_channels(websocketpp::log::alevel::all);
    server_.clear_error_channels(websocketpp::log::elevel::all);

    // Initialize ASIO
    server_.init_asio();

    // Set message handler
    server_.set_message_handler(
        [this](ConnectionHdl hdl, WebSocketServer_t::message_ptr msg) {
          this->onMessage(hdl, msg);
        });

    // Set connection handlers
    server_.set_open_handler([this](ConnectionHdl hdl) { this->onOpen(hdl); });

    server_.set_close_handler(
        [this](ConnectionHdl hdl) { this->onClose(hdl); });

    server_.set_fail_handler([this](ConnectionHdl hdl) { this->onFail(hdl); });

    spdlog::info("WebSocket server initialized successfully");
  } catch (const std::exception &e) {
    spdlog::error("Failed to initialize WebSocket server: {}", e.what());
    throw;
  }
}

void WebSocketServer::start() {
  try {
    spdlog::info("Starting WebSocket server on port {}", port_);

    // Listen on specified port
    server_.listen(port_);

    // Start accepting connections
    server_.start_accept();

    running_ = true;

    // Run the server in a separate thread
    serverThread_ = std::thread([this]() {
      try {
        server_.run();
      } catch (const std::exception &e) {
        spdlog::error("Server thread error: {}", e.what());
      }
    });

    spdlog::info("WebSocket server started successfully");
  } catch (const websocketpp::exception &e) {
    // WebSocket specific error - use error code instead of message to avoid
    // encoding issues
    spdlog::error("Failed to start WebSocket server: error code {}",
                  e.code().value());
    running_ = false;
    throw;
  } catch (const std::exception &e) {
    spdlog::error("Failed to start WebSocket server: {}", e.what());
    running_ = false;
    throw;
  }
}

void WebSocketServer::stop() {
  if (running_) {
    spdlog::info("Stopping WebSocket server");
    running_ = false;

    try {
      // Stop accepting new connections
      server_.stop();

      // Wait for server thread to finish
      if (serverThread_.joinable()) {
        serverThread_.join();
      }

      spdlog::info("WebSocket server stopped successfully");
    } catch (const std::exception &e) {
      spdlog::error("Error stopping WebSocket server: {}", e.what());
    }
  }
}

bool WebSocketServer::isRunning() const { return running_; }

void WebSocketServer::onOpen(ConnectionHdl hdl) {
  try {
    auto con = server_.get_con_from_hdl(hdl);
    std::string endpoint = con->get_remote_endpoint();

    // Store endpoint for later use
    {
      std::lock_guard<std::mutex> lock(connectionMutex_);
      connectionEndpoints_[hdl] = endpoint;
    }

    spdlog::info("Client connected from: {}", endpoint);
  } catch (const std::exception &e) {
    spdlog::error("Error handling connection open: {}", e.what());
  }
}

void WebSocketServer::onClose(ConnectionHdl hdl) {
  std::string endpoint = "Unknown";
  std::string connectionId = getConnectionId(hdl);

  // Retrieve stored endpoint
  {
    std::lock_guard<std::mutex> lock(connectionMutex_);

    auto endpointIt = connectionEndpoints_.find(hdl);
    if (endpointIt != connectionEndpoints_.end()) {
      endpoint = endpointIt->second;
      connectionEndpoints_.erase(endpointIt);
    }
  }

  // Disassociate connection from any stream
  std::string streamId = messageHandler_->getStreamForConnection(connectionId);
  if (!streamId.empty()) {
    messageHandler_->disassociateConnection(connectionId);
    spdlog::info("Client disconnected from: {} (was streaming: {})", endpoint,
                 streamId);
  } else {
    spdlog::info("Client disconnected from: {}", endpoint);
  }
}

void WebSocketServer::onFail(ConnectionHdl hdl) {
  try {
    auto con = server_.get_con_from_hdl(hdl);
    auto ec = con->get_ec();
    // Log error code only to avoid localized messages
    spdlog::info("Connection failed from: {} (error code: {})",
                 con->get_remote_endpoint(), ec.value());
  } catch (const websocketpp::exception &e) {
    spdlog::debug("Connection fail handler error code: {}", e.code().value());
  } catch (const std::exception &e) {
    spdlog::debug("Error handling connection failure: {}", e.what());
  }
}

void WebSocketServer::handleTextMessage(ConnectionHdl hdl,
                                        const std::string &message) {
  std::string connectionId = getConnectionId(hdl);

  auto sendText = [this, hdl](const std::string &msg) {
    this->sendTextMessage(hdl, msg);
  };

  auto sendBinary = [this, hdl](const std::vector<uint8_t> &data) {
    this->sendBinaryMessage(hdl, data);
  };

  messageHandler_->handleTextMessage(message, connectionId, sendText,
                                     sendBinary);
}

void WebSocketServer::handleBinaryMessage(ConnectionHdl hdl,
                                          const std::vector<uint8_t> &data) {
  std::string connectionId = getConnectionId(hdl);

  auto sendText = [this, hdl](const std::string &msg) {
    this->sendTextMessage(hdl, msg);
  };

  messageHandler_->handleBinaryMessage(data, connectionId, sendText);
}

std::string WebSocketServer::getConnectionId(ConnectionHdl hdl) const {
  try {
    // Need to cast away const to call get_con_from_hdl
    auto &non_const_server = const_cast<WebSocketServer_t &>(server_);
    auto con = non_const_server.get_con_from_hdl(hdl);
    return con->get_remote_endpoint();
  } catch (const std::exception &e) {
    spdlog::error("Error getting connection ID: {}", e.what());
    return "unknown";
  }
}

void WebSocketServer::sendTextMessage(ConnectionHdl hdl,
                                      const std::string &message) {
  try {
    server_.send(hdl, message, websocketpp::frame::opcode::text);
    spdlog::debug("Sent text message: {}", message);
  } catch (const websocketpp::exception &e) {
    // Log error code only to avoid localized messages
    spdlog::debug("Error sending text message, error code: {}",
                  e.code().value());
  } catch (const std::exception &e) {
    spdlog::debug("Error sending text message: {}", e.what());
  }
}

void WebSocketServer::sendBinaryMessage(ConnectionHdl hdl,
                                        const std::vector<uint8_t> &data) {
  try {
    std::string binaryData(data.begin(), data.end());
    server_.send(hdl, binaryData, websocketpp::frame::opcode::binary);
    spdlog::debug("Sent binary message: {} bytes", data.size());
  } catch (const websocketpp::exception &e) {
    // Log error code only to avoid localized messages
    spdlog::debug("Error sending binary message, error code: {}",
                  e.code().value());
  } catch (const std::exception &e) {
    spdlog::debug("Error sending binary message: {}", e.what());
  }
}

void WebSocketServer::sendErrorMessage(ConnectionHdl hdl,
                                       const std::string &error) {
  try {
    json errorMsg = {{"type", "error"}, {"message", error}};
    sendTextMessage(hdl, errorMsg.dump());
    spdlog::debug("Sent error message: {}", error);
  } catch (const std::exception &e) {
    spdlog::error("Error sending error message: {}", e.what());
  }
}

} // namespace audio_stream
