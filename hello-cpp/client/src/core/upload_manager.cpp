#include "core/upload_manager.h"
#include "../../include/common_types.h"
#include "util/performance_monitor.h"
#include <chrono>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <thread>

namespace audio_stream {

UploadManager::UploadManager(std::shared_ptr<WebSocketClient> client,
                             std::shared_ptr<ErrorHandler> errorHandler)
    : client_(client), errorHandler_(errorHandler), responseReceived_(false),
      responseTimeoutMs_(5000) {
  // Message handling is now done by main.cpp message router
}

std::string UploadManager::uploadFile(const std::string &filePath) {
  spdlog::info("Starting upload of file: {}", filePath);

  // Validate file exists and is readable
  if (!fileManager_.openForReading(filePath)) {
    if (errorHandler_) {
      errorHandler_->handleFileIOError("Cannot open file for reading",
                                       filePath);
    }
    return "";
  }
  fileManager_.closeReader(); // Close immediately, will reopen later

  // Generate unique stream ID
  currentStreamId_ = streamIdGenerator_.generateStreamId();
  spdlog::info("Generated stream ID: {}", currentStreamId_);

  // Start performance monitoring
  performanceMonitor_.startUpload();

  try {
    // Step 1: Send START message
    if (!sendStartMessage(currentStreamId_)) {
      if (errorHandler_) {
        errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                   "Failed to send START message",
                                   "Stream ID: " + currentStreamId_, false);
      }
      return "";
    }

    // Step 2: Send file chunks
    if (!sendFileChunks(filePath)) {
      if (errorHandler_) {
        errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                   "Failed to send file chunks",
                                   "File: " + filePath, false);
      }
      return "";
    }

    // Step 3: Send STOP message
    if (!sendStopMessage(currentStreamId_)) {
      if (errorHandler_) {
        errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                   "Failed to send STOP message",
                                   "Stream ID: " + currentStreamId_, false);
      }
      return "";
    }

    // End performance monitoring
    performanceMonitor_.endUpload(fileManager_.getFileSize());

    spdlog::info("Successfully uploaded file: {} with stream ID: {}", filePath,
                 currentStreamId_);
    return currentStreamId_;

  } catch (const std::exception &e) {
    if (errorHandler_) {
      errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                 "Exception during upload: " +
                                     std::string(e.what()),
                                 "File: " + filePath, false);
    }
    return "";
  }
}

bool UploadManager::sendStartMessage(const std::string &streamId) {
  spdlog::debug("Sending START message for stream: {}", streamId);

  StartMessage startMsg;
  startMsg.streamId = streamId;

  nlohmann::json j;
  j["type"] = startMsg.type;
  j["streamId"] = startMsg.streamId;
  std::string jsonMessage = j.dump();

  responseReceived_ = false;
  client_->sendTextMessage(jsonMessage);

  // Wait for STARTED response with timeout
  waitForResponse("STARTED", responseTimeoutMs_);

  if (!responseReceived_) {
    if (errorHandler_) {
      errorHandler_->handleTimeoutError(
          "No response received for START message", responseTimeoutMs_);
    }
    return false;
  }

  try {
    nlohmann::json responseJson = nlohmann::json::parse(lastResponse_);
    if (responseJson["type"] == "STARTED") {
      spdlog::info("Received STARTED response: {}",
                   responseJson["message"].get<std::string>());
      return true;
    } else if (responseJson["type"] == "ERROR") {
      std::string errorMsg = responseJson.contains("message")
                                 ? responseJson["message"].get<std::string>()
                                 : "Unknown error";
      return handleProtocolError("Server error in START: " + errorMsg,
                                 "START message");
    } else {
      return handleProtocolError("Unexpected response type: " +
                                     responseJson["type"].get<std::string>(),
                                 "Expected 'started'");
    }
  } catch (const std::exception &e) {
    return handleProtocolError("Failed to parse STARTED response: " +
                                   std::string(e.what()),
                               "JSON parsing");
  }
}

bool UploadManager::sendFileChunks(const std::string &filePath) {
  spdlog::debug("Sending file chunks for: {}", filePath);

  // Open file for reading
  if (!fileManager_.openForReading(filePath)) {
    if (errorHandler_) {
      errorHandler_->handleFileIOError("Failed to open file for reading",
                                       filePath);
    }
    return false;
  }

  size_t totalSize = fileManager_.getFileSize();
  size_t bytesUploaded = 0;

  spdlog::info("File size: {} bytes, estimated chunks: {}", totalSize,
               chunkManager_.calculateChunkCount(totalSize));

  try {
    // Read and send chunks
    while (fileManager_.hasMoreData()) {
      std::vector<uint8_t> chunk;
      size_t bytesRead = fileManager_.readChunk(chunk);

      if (bytesRead == 0) {
        break; // End of file
      }

      // Send chunk as binary message
      client_->sendBinaryMessage(chunk);

      bytesUploaded += bytesRead;

      // Call progress callback if set
      if (progressCallback_) {
        progressCallback_(bytesUploaded, totalSize);
      }

      spdlog::debug("Sent chunk: {} bytes (total: {}/{})", bytesRead,
                    bytesUploaded, totalSize);
    }

    fileManager_.closeReader();

    spdlog::info("Finished sending {} bytes in chunks", bytesUploaded);
    return true;

  } catch (const std::exception &e) {
    fileManager_.closeReader();
    if (errorHandler_) {
      errorHandler_->reportError(ErrorHandler::ErrorType::FILE_IO_ERROR,
                                 "Exception while reading file chunks: " +
                                     std::string(e.what()),
                                 "File: " + filePath, false);
    }
    return false;
  }
}

bool UploadManager::handleProtocolError(const std::string &message,
                                        const std::string &context) {
  if (errorHandler_) {
    errorHandler_->handleProtocolError(message, context);
  } else {
    spdlog::error("Protocol error: {} (Context: {})", message, context);
  }
  return false;
}

bool UploadManager::sendStopMessage(const std::string &streamId) {
  spdlog::debug("Sending STOP message for stream: {}", streamId);

  StopMessage stopMsg;
  stopMsg.streamId = streamId;

  nlohmann::json j;
  j["type"] = stopMsg.type;
  j["streamId"] = stopMsg.streamId;
  std::string jsonMessage = j.dump();

  responseReceived_ = false;
  client_->sendTextMessage(jsonMessage);

  // Wait for STOPPED response with timeout
  waitForResponse("STOPPED", responseTimeoutMs_);

  if (!responseReceived_) {
    if (errorHandler_) {
      errorHandler_->handleTimeoutError("No response received for STOP message",
                                        responseTimeoutMs_);
    }
    return false;
  }

  try {
    nlohmann::json responseJson = nlohmann::json::parse(lastResponse_);
    if (responseJson["type"] == "STOPPED") {
      spdlog::info("Received STOPPED response: {}",
                   responseJson["message"].get<std::string>());
      return true;
    } else if (responseJson["type"] == "ERROR") {
      std::string errorMsg = responseJson.contains("message")
                                 ? responseJson["message"].get<std::string>()
                                 : "Unknown error";
      return handleProtocolError("Server error in STOP: " + errorMsg,
                                 "STOP message");
    } else {
      return handleProtocolError("Unexpected response type: " +
                                     responseJson["type"].get<std::string>(),
                                 "Expected 'STOPPED'");
    }
  } catch (const std::exception &e) {
    return handleProtocolError("Failed to parse STOPPED response: " +
                                   std::string(e.what()),
                               "JSON parsing");
  }
}

void UploadManager::waitForResponse(const std::string &expectedType,
                                    int timeoutMs) {
  auto startTime = std::chrono::steady_clock::now();
  auto timeout = std::chrono::milliseconds(timeoutMs);

  while (!responseReceived_) {
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    auto elapsed = std::chrono::steady_clock::now() - startTime;
    if (elapsed > timeout) {
      spdlog::warn("Timeout waiting for {} response", expectedType);
      break;
    }
  }
}

void UploadManager::setProgressCallback(
    std::function<void(size_t, size_t)> callback) {
  progressCallback_ = callback;
}

PerformanceMetrics UploadManager::getPerformanceMetrics() const {
  return performanceMonitor_.getMetrics();
}

void UploadManager::handleServerResponse(const std::string &message) {
  spdlog::debug("Received server response: {}", message);
  lastResponse_ = message;
  responseReceived_ = true;
}

} // namespace audio_stream