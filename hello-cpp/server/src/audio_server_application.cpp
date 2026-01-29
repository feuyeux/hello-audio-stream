#include "audio_server_application.h"
#include "../include/common_types.h"
#include "network/audio_websocket_server.h"
#include <chrono>
#include <csignal>
#include <iostream>
#include <spdlog/spdlog.h>
#include <string>
#include <thread>

using namespace audio_stream;

static bool running = true;

void signalHandler(int signal) {
  if (signal == SIGINT || signal == SIGTERM) {
    spdlog::info("Received shutdown signal");
    running = false;
  }
}

int main(int argc, char *argv[]) {
  spdlog::set_level(spdlog::level::info);
  spdlog::info("Audio Stream Cache Server - C++ Implementation");

  // Parse command-line arguments
  int port = DEFAULT_PORT;
  std::string path = DEFAULT_PATH;

  if (argc >= 2) {
    port = std::stoi(argv[1]);
  }
  if (argc >= 3) {
    path = argv[2];
  }

  spdlog::info("Starting server on port {} with path {}", port, path);

  // Set up signal handlers
  std::signal(SIGINT, signalHandler);
  std::signal(SIGTERM, signalHandler);

  try {
    // Create and start WebSocket server
    WebSocketServer server(port, path);
    server.start();

    spdlog::info("Server started successfully. Press Ctrl+C to stop.");

    // Keep running until signal received
    while (running) {
      std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    // Stop server gracefully
    server.stop();

  } catch (const websocketpp::exception &e) {
    // WebSocket specific error - use error code to avoid encoding issues
    spdlog::error("Server error: WebSocket exception with error code {}",
                  e.code().value());
    return 1;
  } catch (const std::exception &e) {
    spdlog::error("Server error: {}", e.what());
    return 1;
  }

  spdlog::info("Server shutting down");
  return 0;
}
