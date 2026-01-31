#ifndef AUDIO_STREAM_PERFORMANCE_MONITOR_H
#define AUDIO_STREAM_PERFORMANCE_MONITOR_H

#include "../../include/common_types.h"
#include <chrono>
#include <fstream>
#include <string>

namespace audio_stream {

/**
 * Performance monitor for tracking stream metrics
 * Records timestamps and calculates throughput
 * Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
 */
class PerformanceMonitor {
public:
  PerformanceMonitor() = default;

  // Upload metrics
  void startUpload();
  void endUpload(size_t bytes);

  // Download metrics
  void startDownload();
  void endDownload(size_t bytes);

  // Get metrics
  PerformanceMetrics getMetrics() const;
  std::string generateReport() const;

  // Logging functionality
  void logMetricsToConsole() const;
  void logMetricsToFile(const std::string &filePath) const;

  // Performance validation
  bool meetsPerformanceTargets() const;

private:
  double
  calculateThroughputMbps(size_t bytes,
                          std::chrono::steady_clock::time_point start,
                          std::chrono::steady_clock::time_point end) const;

  std::string formatBytes(size_t bytes) const;

  PerformanceMetrics metrics_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_PERFORMANCE_MONITOR_H
