#ifndef DOWNLOAD_MANAGER_H
#define DOWNLOAD_MANAGER_H

#include "../../include/common_types.h"
#include "core/chunk_manager.h"
#include "core/file_manager.h"
#include "core/websocket_client.h"
#include "util/error_handler.h"
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <vector>

namespace audio_stream {

/**
 * Download manager for orchestrating file downloads from the server.
 * Handles GET request sequencing, binary frame assembly, and file writing.
 *
 * Requirements: 7.1, 7.3, 7.6, 7.7
 */
class DownloadManager {
public:
  /**
   * Construct a download manager.
   * @param client WebSocket client for communication
   * @param fileManager File manager for writing downloaded data
   * @param chunkManager Chunk manager for assembling data
   * @param errorHandler Error handler for reporting errors (optional)
   */
  DownloadManager(std::shared_ptr<WebSocketClient> client,
                  std::shared_ptr<FileManager> fileManager,
                  std::shared_ptr<ChunkManager> chunkManager,
                  std::shared_ptr<ErrorHandler> errorHandler = nullptr);

  /**
   * Download a file from the server.
   * @param streamId Stream identifier to download from
   * @param outputPath Path to write the downloaded file
   * @param expectedSize Expected size of the file (0 if unknown)
   * @return true if download was successful, false otherwise
   */
  bool downloadFile(const std::string &streamId, const std::string &outputPath,
                    size_t expectedSize = 0);

  /**
   * Get the last error message.
   * @return Error message string
   */
  const std::string &getLastError() const { return lastError_; }

  /**
   * Get download progress (0.0 to 1.0).
   * @return Progress as a fraction
   */
  double getProgress() const;

  /**
   * Get total bytes downloaded.
   * @return Number of bytes downloaded
   */
  size_t getBytesDownloaded() const { return bytesDownloaded_; }

  /**
   * Set timeout for GET requests
   * @param timeoutMs Timeout in milliseconds
   */
  void setRequestTimeout(int timeoutMs) { requestTimeoutMs_ = timeoutMs; }

  /**
   * Set maximum retry attempts for failed requests
   * @param maxRetries Maximum number of retry attempts
   */
  void setMaxRetries(int maxRetries) { maxRetries_ = maxRetries; }

  /**
   * Handle server response message (called from main message router)
   * @param message Server response message
   */
  void handleServerResponse(const std::string &message) {
    onTextMessageReceived(message);
  }

private:
  /**
   * Send a GET request for a specific chunk.
   * @param streamId Stream identifier
   * @param offset Byte offset to request
   * @param length Number of bytes to request
   * @return true if request was sent successfully
   */
  bool sendGetRequest(const std::string &streamId, size_t offset,
                      size_t length);

  /**
   * Receive and process binary data from the server.
   * @param data Binary data received
   * @return true if data was processed successfully
   */
  bool processBinaryData(const std::vector<uint8_t> &data);

  /**
   * Wait for binary data with timeout.
   * @param timeoutMs Timeout in milliseconds
   * @return Binary data received, empty if timeout or error
   */
  std::vector<uint8_t> waitForBinaryData(int timeoutMs = 5000);

  /**
   * Callback for binary data received from WebSocket.
   * @param data Binary data received
   */
  void onBinaryDataReceived(const std::vector<uint8_t> &data);

  /**
   * Callback for text messages received from WebSocket.
   * @param message Text message received
   */
  void onTextMessageReceived(const std::string &message);

  /**
   * Handle protocol errors with proper error reporting
   * @param message Error message
   * @param context Error context
   * @return false (always fails)
   */
  bool handleProtocolError(const std::string &message,
                           const std::string &context);

  std::shared_ptr<WebSocketClient> client_;
  std::shared_ptr<FileManager> fileManager_;
  std::shared_ptr<ChunkManager> chunkManager_;
  std::shared_ptr<ErrorHandler> errorHandler_;

  std::string lastError_;
  size_t bytesDownloaded_;
  size_t totalSize_;
  std::vector<uint8_t> downloadBuffer_;
  int requestTimeoutMs_;
  int maxRetries_;

  // Synchronization for async message handling
  std::queue<std::vector<uint8_t>> pendingData_;
  std::mutex dataMutex_;
  std::condition_variable dataCondition_;
  bool downloadComplete_;
  bool errorOccurred_;

  static constexpr size_t CHUNK_SIZE = 65536; // 64KB chunks
};

} // namespace audio_stream

#endif // DOWNLOAD_MANAGER_H