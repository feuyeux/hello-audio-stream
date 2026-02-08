#include "core/websocket_client.h"
#include <chrono>
#include <spdlog/spdlog.h>
#include <thread>

namespace audio_stream {

WebSocketClient::WebSocketClient(const std::string &uri)
    : uri_(uri), connected_(false) {
  // Initialize WebSocket client
  client_.init_asio();

  // Clear access and error logs for cleaner output
  client_.clear_access_channels(websocketpp::log::alevel::all);
  client_.clear_error_channels(websocketpp::log::elevel::all);

  // Set up handlers
  client_.set_open_handler([this](ConnectionHdl hdl) { this->onOpen(hdl); });

  client_.set_close_handler([this](ConnectionHdl hdl) { this->onClose(hdl); });

  client_.set_fail_handler([this](ConnectionHdl hdl) { this->onFail(hdl); });

  client_.set_message_handler(
      [this](ConnectionHdl hdl, auto msg) { this->onMessage(hdl, msg); });

  spdlog::debug("WebSocketClient created for URI: {}", uri);
}

WebSocketClient::~WebSocketClient() { disconnect(); }

bool WebSocketClient::connect() {
  return connectWithRetry(1); // Single attempt for backward compatibility
}

bool WebSocketClient::connectWithRetry(int maxRetries) {
  for (int attempt = 1; attempt <= maxRetries; ++attempt) {
    spdlog::info("Connection attempt {}/{} to {}", attempt, maxRetries, uri_);

    if (attemptConnection()) {
      spdlog::info("Successfully connected to {} on attempt {}", uri_, attempt);
      return true;
    }

    if (attempt < maxRetries) {
      spdlog::warn("Connection attempt {} failed, retrying...", attempt);
      waitWithExponentialBackoff(attempt);
    } else {
      spdlog::error("All {} connection attempts failed to {}", maxRetries,
                    uri_);
    }
  }

  return false;
}

bool WebSocketClient::attemptConnection() {
  try {
    websocketpp::lib::error_code ec;
    WebSocketClient_t::connection_ptr con = client_.get_connection(uri_, ec);

    if (ec) {
      spdlog::error("Connection initialization error: {}", ec.message());
      if (onErrorHandler_) {
        onErrorHandler_("Connection initialization error: " + ec.message());
      }
      return false;
    }

    connection_ = con->get_handle();
    client_.connect(con);

    // Run the client in a separate thread
    std::thread([this]() {
      try {
        client_.run();
      } catch (const std::exception &e) {
        spdlog::error("WebSocket client run exception: {}", e.what());
        if (onErrorHandler_) {
          onErrorHandler_(std::string("Client run exception: ") + e.what());
        }
      }
    }).detach();

    // Wait for connection to establish with timeout
    auto startTime = std::chrono::steady_clock::now();
    auto timeout = std::chrono::milliseconds(DEFAULT_TIMEOUT_MS);

    while (!connected_ &&
           (std::chrono::steady_clock::now() - startTime) < timeout) {
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    return connected_;
  } catch (const std::exception &e) {
    spdlog::error("Exception during connection attempt: {}", e.what());
    if (onErrorHandler_) {
      onErrorHandler_(std::string("Exception during connection: ") + e.what());
    }
    return false;
  }
}

void WebSocketClient::waitWithExponentialBackoff(int attempt) {
  // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 32s
  int delayMs = std::min(1000 * (1 << (attempt - 1)), 32000);
  spdlog::info("Waiting {} ms before next connection attempt", delayMs);
  std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
}

void WebSocketClient::disconnect() {
  if (connected_) {
    try {
      spdlog::info("Disconnecting from {}", uri_);

      websocketpp::lib::error_code ec;
      client_.close(connection_, websocketpp::close::status::normal,
                    "Client disconnect", ec);

      if (ec) {
        spdlog::error("Disconnect error: {}", ec.message());
      }

      connected_ = false;
    } catch (const std::exception &e) {
      spdlog::error("Exception during disconnect: {}", e.what());
    }
  }

  // Stop the client
  client_.stop();
}

bool WebSocketClient::isConnected() const { return connected_; }

void WebSocketClient::sendTextMessage(const std::string &message) {
  if (!connected_) {
    spdlog::error("Cannot send text message: not connected");
    if (onErrorHandler_) {
      onErrorHandler_("Cannot send text message: not connected");
    }
    return;
  }

  try {
    spdlog::debug("Sending text message: {}", message);

    websocketpp::lib::error_code ec;
    client_.send(connection_, message, websocketpp::frame::opcode::text, ec);

    if (ec) {
      spdlog::error("Send text error: {}", ec.message());
      if (onErrorHandler_) {
        onErrorHandler_("Send text error: " + ec.message());
      }
    }
  } catch (const std::exception &e) {
    spdlog::error("Exception during send text: {}", e.what());
    if (onErrorHandler_) {
      onErrorHandler_(std::string("Exception during send text: ") + e.what());
    }
  }
}

void WebSocketClient::sendBinaryMessage(const std::vector<uint8_t> &data) {
  if (!connected_) {
    spdlog::error("Cannot send binary message: not connected");
    if (onErrorHandler_) {
      onErrorHandler_("Cannot send binary message: not connected");
    }
    return;
  }

  try {
    spdlog::debug("Sending binary message: {} bytes", data.size());

    websocketpp::lib::error_code ec;
    client_.send(connection_, data.data(), data.size(),
                 websocketpp::frame::opcode::binary, ec);

    if (ec) {
      spdlog::error("Send binary error: {}", ec.message());
      if (onErrorHandler_) {
        onErrorHandler_("Send binary error: " + ec.message());
      }
    }
  } catch (const std::exception &e) {
    spdlog::error("Exception during send binary: {}", e.what());
    if (onErrorHandler_) {
      onErrorHandler_(std::string("Exception during send binary: ") + e.what());
    }
  }
}

void WebSocketClient::setOnMessage(
    std::function<void(const std::string &)> handler) {
  onMessageHandler_ = handler;
}

void WebSocketClient::setOnBinaryMessage(
    std::function<void(const std::vector<uint8_t> &)> handler) {
  onBinaryMessageHandler_ = handler;
}

void WebSocketClient::setOnError(
    std::function<void(const std::string &)> handler) {
  onErrorHandler_ = handler;
}

void WebSocketClient::onOpen(ConnectionHdl hdl) {
  connection_ = hdl;
  connected_ = true;
  spdlog::info("Connection opened successfully");
}

void WebSocketClient::onClose([[maybe_unused]] ConnectionHdl hdl) {
  connected_ = false;
  spdlog::info("Connection closed");
}

void WebSocketClient::onFail([[maybe_unused]] ConnectionHdl hdl) {
  connected_ = false;

  try {
    spdlog::error("Connection failed");
    if (onErrorHandler_) {
      onErrorHandler_("Connection failed");
    }
  } catch (const std::exception &e) {
    spdlog::error("Connection failed with exception: {}", e.what());
    if (onErrorHandler_) {
      onErrorHandler_(std::string("Connection failed: ") + e.what());
    }
  }
}

} // namespace audio_stream
