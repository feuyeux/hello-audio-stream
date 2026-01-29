#include "util/error_handler.h"
#include <algorithm>
#include <spdlog/spdlog.h>
#include <thread>

namespace audio_stream {

void ErrorHandler::reportError(ErrorType type, const std::string &message,
                               const std::string &context, bool recoverable) {
  ErrorInfo error;
  error.type = type;
  error.message = message;
  error.context = context;
  error.timestamp = std::chrono::steady_clock::now();
  error.recoverable = recoverable;

  incrementErrorCount(type);

  // Log the error
  std::string logMessage = "[" + errorTypeToString(type) + "] " + message;
  if (!context.empty()) {
    logMessage += " (Context: " + context + ")";
  }

  if (recoverable) {
    spdlog::warn("{} - Recoverable", logMessage);
  } else {
    spdlog::error("{} - Not recoverable", logMessage);
  }

  // Call error callback if set
  if (onErrorCallback_) {
    onErrorCallback_(error);
  }
}

bool ErrorHandler::handleConnectionError(const std::string &message,
                                         int &retryCount, int maxRetries) {
  reportError(ErrorType::CONNECTION_ERROR, message,
              "Connection attempt " + std::to_string(retryCount), true);

  if (retryCount >= maxRetries) {
    spdlog::error("Maximum connection retries ({}) exceeded", maxRetries);
    return false;
  }

  int delayMs = getRetryDelayMs(retryCount);
  spdlog::info("Retrying connection in {} ms (attempt {}/{})", delayMs,
               retryCount + 1, maxRetries);

  std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
  retryCount++;

  return true;
}

bool ErrorHandler::handleFileIOError(const std::string &message,
                                     const std::string &filePath) {
  reportError(ErrorType::FILE_IO_ERROR, message, "File: " + filePath, false);

  // File I/O errors are generally not recoverable
  spdlog::error("File I/O error is not recoverable: {}", message);
  return false;
}

bool ErrorHandler::handleProtocolError(const std::string &message,
                                       const std::string &expectedFormat) {
  std::string context =
      expectedFormat.empty() ? "" : "Expected: " + expectedFormat;
  reportError(ErrorType::PROTOCOL_ERROR, message, context, false);

  // Protocol errors are generally not recoverable
  spdlog::error("Protocol error is not recoverable: {}", message);
  return false;
}

bool ErrorHandler::handleTimeoutError(const std::string &message,
                                      int timeoutMs) {
  reportError(ErrorType::TIMEOUT_ERROR, message,
              "Timeout: " + std::to_string(timeoutMs) + "ms", true);

  // Timeout errors might be recoverable with retry
  spdlog::warn("Timeout error occurred, may be recoverable: {}", message);
  return true;
}

bool ErrorHandler::shouldRetry(ErrorType type, int currentAttempt,
                               int maxAttempts) {
  if (currentAttempt >= maxAttempts) {
    return false;
  }

  switch (type) {
  case ErrorType::CONNECTION_ERROR:
  case ErrorType::TIMEOUT_ERROR:
    return true;
  case ErrorType::FILE_IO_ERROR:
  case ErrorType::PROTOCOL_ERROR:
  case ErrorType::VALIDATION_ERROR:
  default:
    return false;
  }
}

int ErrorHandler::getRetryDelayMs(int attempt) {
  // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 32s
  return std::min(1000 * (1 << attempt), 32000);
}

void ErrorHandler::setOnError(std::function<void(const ErrorInfo &)> callback) {
  onErrorCallback_ = callback;
}

int ErrorHandler::getErrorCount(ErrorType type) const {
  switch (type) {
  case ErrorType::CONNECTION_ERROR:
    return connectionErrors_;
  case ErrorType::FILE_IO_ERROR:
    return fileIOErrors_;
  case ErrorType::PROTOCOL_ERROR:
    return protocolErrors_;
  case ErrorType::TIMEOUT_ERROR:
    return timeoutErrors_;
  case ErrorType::VALIDATION_ERROR:
    return validationErrors_;
  default:
    return 0;
  }
}

void ErrorHandler::clearErrorCounts() {
  connectionErrors_ = 0;
  fileIOErrors_ = 0;
  protocolErrors_ = 0;
  timeoutErrors_ = 0;
  validationErrors_ = 0;
}

void ErrorHandler::incrementErrorCount(ErrorType type) {
  switch (type) {
  case ErrorType::CONNECTION_ERROR:
    connectionErrors_++;
    break;
  case ErrorType::FILE_IO_ERROR:
    fileIOErrors_++;
    break;
  case ErrorType::PROTOCOL_ERROR:
    protocolErrors_++;
    break;
  case ErrorType::TIMEOUT_ERROR:
    timeoutErrors_++;
    break;
  case ErrorType::VALIDATION_ERROR:
    validationErrors_++;
    break;
  }
}

std::string ErrorHandler::errorTypeToString(ErrorType type) const {
  switch (type) {
  case ErrorType::CONNECTION_ERROR:
    return "CONNECTION_ERROR";
  case ErrorType::FILE_IO_ERROR:
    return "FILE_IO_ERROR";
  case ErrorType::PROTOCOL_ERROR:
    return "PROTOCOL_ERROR";
  case ErrorType::TIMEOUT_ERROR:
    return "TIMEOUT_ERROR";
  case ErrorType::VALIDATION_ERROR:
    return "VALIDATION_ERROR";
  default:
    return "UNKNOWN_ERROR";
  }
}

} // namespace audio_stream