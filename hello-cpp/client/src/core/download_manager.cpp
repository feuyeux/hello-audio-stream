#include "core/download_manager.h"
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <thread>

// Undefine Windows macros that conflict with our code
#ifdef GetMessage
#undef GetMessage
#endif

namespace audio_stream {

DownloadManager::DownloadManager(std::shared_ptr<WebSocketClient> client,
                                 std::shared_ptr<FileManager> fileManager,
                                 std::shared_ptr<ChunkManager> chunkManager,
                                 std::shared_ptr<ErrorHandler> errorHandler)
    : client_(client), fileManager_(fileManager), chunkManager_(chunkManager),
      errorHandler_(errorHandler), bytesDownloaded_(0), totalSize_(0),
      requestTimeoutMs_(5000), maxRetries_(3), downloadComplete_(false),
      errorOccurred_(false) {

  // Set up binary message handler for receiving data
  client_->setOnBinaryMessage([this](const std::vector<uint8_t> &data) {
    this->onBinaryDataReceived(data);
  });

  // Text message handling is now done by main.cpp message router
}

bool DownloadManager::downloadFile(const std::string &streamId,
                                   const std::string &outputPath,
                                   size_t expectedSize) {
  spdlog::info("Starting download: streamId={}, outputPath={}, expectedSize={}",
               streamId, outputPath, expectedSize);

  // Reset state
  bytesDownloaded_ = 0;
  totalSize_ = expectedSize;
  lastError_.clear();
  downloadBuffer_.clear();
  // Clear the queue by swapping with an empty queue
  std::queue<std::vector<uint8_t>> empty;
  pendingData_.swap(empty);
  downloadComplete_ = false;
  errorOccurred_ = false;

  // Open output file for writing
  if (!fileManager_->openForWriting(outputPath)) {
    lastError_ = "Failed to open output file: " + outputPath;
    if (errorHandler_) {
      errorHandler_->handleFileIOError(lastError_, outputPath);
    }
    return false;
  }

  // If expected size is unknown, start with first chunk to determine size
  size_t currentOffset = 0;
  size_t remainingBytes = expectedSize > 0 ? expectedSize : CHUNK_SIZE;

  while (remainingBytes > 0 || expectedSize == 0) {
    // Calculate chunk size for this request
    size_t requestSize = std::min(remainingBytes, CHUNK_SIZE);

    spdlog::debug("Requesting chunk: offset={}, size={}", currentOffset,
                  requestSize);

    // Send GET request with retry logic
    int retryCount = 0;
    bool requestSuccess = false;

    while (retryCount <= maxRetries_ && !requestSuccess) {
      if (!sendGetRequest(streamId, currentOffset, requestSize)) {
        retryCount++;
        if (retryCount <= maxRetries_) {
          if (errorHandler_) {
            errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                       "GET request failed, retrying",
                                       "Attempt " + std::to_string(retryCount),
                                       true);
          }
          std::this_thread::sleep_for(
              std::chrono::milliseconds(1000 * retryCount));
          continue;
        } else {
          fileManager_->closeWriter();
          return false;
        }
      }
      requestSuccess = true;
    }

    // Wait for binary response with timeout
    std::vector<uint8_t> chunkData = waitForBinaryData(requestTimeoutMs_);
    if (chunkData.empty()) {
      if (expectedSize == 0 && bytesDownloaded_ > 0) {
        // End of file reached for unknown size
        spdlog::info("End of file reached at {} bytes", bytesDownloaded_);
        break;
      }
      if (errorOccurred_) {
        fileManager_->closeWriter();
        return false;
      }
      lastError_ = "Failed to receive chunk data";
      if (errorHandler_) {
        errorHandler_->handleTimeoutError(lastError_, requestTimeoutMs_);
      }
      fileManager_->closeWriter();
      return false;
    }

    // Process the received data
    if (!processBinaryData(chunkData)) {
      fileManager_->closeWriter();
      return false;
    }

    // Update progress
    currentOffset += chunkData.size();
    bytesDownloaded_ += chunkData.size();

    if (expectedSize > 0) {
      remainingBytes -= chunkData.size();
    } else {
      // For unknown size, continue until we get less than requested
      if (chunkData.size() < requestSize) {
        spdlog::info("Received partial chunk, download complete");
        break;
      }
    }

    // Log progress periodically
    if (bytesDownloaded_ % (CHUNK_SIZE * 10) == 0) {
      spdlog::info("Downloaded {} bytes", bytesDownloaded_);
    }
  }

  // Close output file
  fileManager_->closeWriter();

  spdlog::info("Download completed: {} bytes downloaded", bytesDownloaded_);
  return true;
}

bool DownloadManager::sendGetRequest(const std::string &streamId, size_t offset,
                                     size_t length) {
  try {
    // Create GET control message using the audio_stream namespace
    audio_stream::GetMessage getMsg(streamId, static_cast<int64_t>(offset),
                                    static_cast<int64_t>(length));

    // Serialize to JSON
    std::string jsonMessage = getMsg.toJson();

    // Send as text message
    client_->sendTextMessage(jsonMessage);

    spdlog::debug("Sent GET request: {}", jsonMessage);
    return true;

  } catch (const std::exception &e) {
    lastError_ = "Exception in sendGetRequest: " + std::string(e.what());
    if (errorHandler_) {
      errorHandler_->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                 lastError_, "GET request", false);
    }
    return false;
  }
}

bool DownloadManager::processBinaryData(const std::vector<uint8_t> &data) {
  try {
    // Write data to file
    if (!fileManager_->write(data)) {
      lastError_ = "Failed to write chunk to file";
      if (errorHandler_) {
        errorHandler_->handleFileIOError(lastError_, "Output file");
      }
      return false;
    }

    spdlog::debug("Processed {} bytes of binary data", data.size());
    return true;

  } catch (const std::exception &e) {
    lastError_ = "Exception in processBinaryData: " + std::string(e.what());
    if (errorHandler_) {
      errorHandler_->reportError(ErrorHandler::ErrorType::FILE_IO_ERROR,
                                 lastError_, "File write operation", false);
    }
    return false;
  }
}

std::vector<uint8_t> DownloadManager::waitForBinaryData(int timeoutMs) {
  std::unique_lock<std::mutex> lock(dataMutex_);

  // Wait for data or timeout
  auto timeout = std::chrono::milliseconds(timeoutMs);
  if (dataCondition_.wait_for(lock, timeout, [this] {
        return !pendingData_.empty() || errorOccurred_;
      })) {
    if (errorOccurred_) {
      return {};
    }
    if (!pendingData_.empty()) {
      std::vector<uint8_t> data = std::move(pendingData_.front());
      pendingData_.pop();
      return data;
    }
  }

  // Timeout occurred
  lastError_ = "Timeout waiting for binary data";
  if (errorHandler_) {
    errorHandler_->handleTimeoutError(lastError_, timeoutMs);
  }
  return {};
}

void DownloadManager::onBinaryDataReceived(const std::vector<uint8_t> &data) {
  std::lock_guard<std::mutex> lock(dataMutex_);
  pendingData_.push(data);
  dataCondition_.notify_one();
  spdlog::debug("Binary data received: {} bytes", data.size());
}

void DownloadManager::onTextMessageReceived(const std::string &message) {
  spdlog::debug("Text message received during download: {}", message);

  // Parse as control message to check for errors
  try {
    // Try to parse as error message
    nlohmann::json j = nlohmann::json::parse(message);
    if (j.contains("type") && j["type"] == "error") {
      std::string errorMsg =
          j.contains("message") ? j["message"] : "Unknown error";
      lastError_ = "Server error: " + errorMsg;
      spdlog::error(lastError_);

      std::lock_guard<std::mutex> lock(dataMutex_);
      errorOccurred_ = true;
      dataCondition_.notify_one();
    }
  } catch (...) {
    // Ignore parsing errors for unexpected text messages
  }
}

double DownloadManager::getProgress() const {
  if (totalSize_ == 0) {
    return 0.0;
  }
  return static_cast<double>(bytesDownloaded_) /
         static_cast<double>(totalSize_);
}

bool DownloadManager::handleProtocolError(const std::string &message,
                                          const std::string &context) {
  if (errorHandler_) {
    errorHandler_->handleProtocolError(message, context);
  } else {
    spdlog::error("Protocol error: {} (Context: {})", message, context);
  }
  return false;
}

} // namespace audio_stream