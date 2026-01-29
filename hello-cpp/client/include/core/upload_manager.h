#ifndef AUDIO_STREAM_UPLOAD_MANAGER_H
#define AUDIO_STREAM_UPLOAD_MANAGER_H

#include "../../include/common_types.h"
#include "core/chunk_manager.h"
#include "core/file_manager.h"
#include "core/websocket_client.h"
#include "util/error_handler.h"
#include "util/performance_monitor.h"
#include "util/stream_id_generator.h"
#include <functional>
#include <memory>
#include <string>

namespace audio_stream {

/**
 * Upload manager for orchestrating file upload workflow
 * Handles the complete upload process: START -> chunks -> STOP
 */
class UploadManager {
public:
  UploadManager(std::shared_ptr<WebSocketClient> client,
                std::shared_ptr<ErrorHandler> errorHandler = nullptr);
  ~UploadManager() = default;

  /**
   * Upload a file to the server
   * @param filePath Path to the file to upload
   * @return Generated stream ID if successful, empty string if failed
   */
  std::string uploadFile(const std::string &filePath);

  /**
   * Set callback for upload progress
   * @param callback Function called with (bytesUploaded, totalBytes)
   */
  void setProgressCallback(std::function<void(size_t, size_t)> callback);

  /**
   * Get performance metrics from last upload
   * @return Performance metrics
   */
  PerformanceMetrics getPerformanceMetrics() const;

  /**
   * Set timeout for server responses
   * @param timeoutMs Timeout in milliseconds
   */
  void setResponseTimeout(int timeoutMs) { responseTimeoutMs_ = timeoutMs; }

  /**
   * Handle server response message (called from main message router)
   * @param message Server response message
   */
  void handleServerResponse(const std::string &message);

private:
  bool sendStartMessage(const std::string &streamId);
  bool sendFileChunks(const std::string &filePath);
  bool sendStopMessage(const std::string &streamId);
  void waitForResponse(const std::string &expectedType, int timeoutMs = 5000);
  bool handleProtocolError(const std::string &message,
                           const std::string &context);

  std::shared_ptr<WebSocketClient> client_;
  std::shared_ptr<ErrorHandler> errorHandler_;
  FileManager fileManager_;
  ChunkManager chunkManager_;
  StreamIdGenerator streamIdGenerator_;
  PerformanceMonitor performanceMonitor_;

  std::function<void(size_t, size_t)> progressCallback_;
  std::string lastResponse_;
  bool responseReceived_;
  std::string currentStreamId_;
  int responseTimeoutMs_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_UPLOAD_MANAGER_H