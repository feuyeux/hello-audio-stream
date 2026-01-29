#ifndef AUDIO_STREAM_ERROR_HANDLER_H
#define AUDIO_STREAM_ERROR_HANDLER_H

#include <chrono>
#include <functional>
#include <string>

namespace audio_stream {

/**
 * Centralized error handling for the audio stream client
 * Provides consistent error handling, logging, and recovery strategies
 */
class ErrorHandler {
public:
  enum class ErrorType {
    CONNECTION_ERROR,
    FILE_IO_ERROR,
    PROTOCOL_ERROR,
    TIMEOUT_ERROR,
    VALIDATION_ERROR
  };

  struct ErrorInfo {
    ErrorType type;
    std::string message;
    std::string context;
    std::chrono::steady_clock::time_point timestamp;
    bool recoverable;
  };

  ErrorHandler() = default;

  // Error reporting
  void reportError(ErrorType type, const std::string &message,
                   const std::string &context = "", bool recoverable = false);

  // Error handling strategies
  bool handleConnectionError(const std::string &message, int &retryCount,
                             int maxRetries = 10);
  bool handleFileIOError(const std::string &message,
                         const std::string &filePath);
  bool handleProtocolError(const std::string &message,
                           const std::string &expectedFormat = "");
  bool handleTimeoutError(const std::string &message, int timeoutMs);

  // Recovery strategies
  bool shouldRetry(ErrorType type, int currentAttempt, int maxAttempts = 3);
  int getRetryDelayMs(int attempt);

  // Error callbacks
  void setOnError(std::function<void(const ErrorInfo &)> callback);

  // Statistics
  int getErrorCount(ErrorType type) const;
  void clearErrorCounts();

private:
  std::function<void(const ErrorInfo &)> onErrorCallback_;

  // Error counters
  int connectionErrors_ = 0;
  int fileIOErrors_ = 0;
  int protocolErrors_ = 0;
  int timeoutErrors_ = 0;
  int validationErrors_ = 0;

  void incrementErrorCount(ErrorType type);
  std::string errorTypeToString(ErrorType type) const;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_ERROR_HANDLER_H