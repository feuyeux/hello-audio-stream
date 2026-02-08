#include "util/performance_monitor.h"
#include <iomanip>
#include <spdlog/spdlog.h>
#include <sstream>

namespace audio_stream {

void PerformanceMonitor::startUpload() {
  metrics_.uploadStartTime = std::chrono::steady_clock::now();
  spdlog::debug("Upload started at timestamp");
}

void PerformanceMonitor::endUpload(size_t bytes) {
  metrics_.uploadEndTime = std::chrono::steady_clock::now();
  metrics_.uploadBytes = bytes;
  metrics_.uploadThroughputMbps = calculateThroughputMbps(
      bytes, metrics_.uploadStartTime, metrics_.uploadEndTime);

  spdlog::info("Upload completed: {} bytes, {:.2f} Mbps", bytes,
               metrics_.uploadThroughputMbps);
}

void PerformanceMonitor::startDownload() {
  metrics_.downloadStartTime = std::chrono::steady_clock::now();
  spdlog::debug("Download started at timestamp");
}

void PerformanceMonitor::endDownload(size_t bytes) {
  metrics_.downloadEndTime = std::chrono::steady_clock::now();
  metrics_.downloadBytes = bytes;
  metrics_.downloadThroughputMbps = calculateThroughputMbps(
      bytes, metrics_.downloadStartTime, metrics_.downloadEndTime);

  spdlog::info("Download completed: {} bytes, {:.2f} Mbps", bytes,
               metrics_.downloadThroughputMbps);
}

PerformanceMetrics PerformanceMonitor::getMetrics() const { return metrics_; }

std::string PerformanceMonitor::generateReport() const {
  std::ostringstream oss;
  oss << std::fixed << std::setprecision(2);

  oss << "=== Performance Report ===\n";

  // Upload metrics
  if (metrics_.uploadBytes > 0) {
    auto uploadDuration = std::chrono::duration_cast<std::chrono::milliseconds>(
        metrics_.uploadEndTime - metrics_.uploadStartTime);

    oss << "Upload Performance:\n";
    oss << "  Bytes transferred: " << formatBytes(metrics_.uploadBytes) << "\n";
    oss << "  Duration: " << uploadDuration.count() << " ms\n";
    oss << "  Throughput: " << metrics_.uploadThroughputMbps << " Mbps\n";
    oss << "  Target: >100 Mbps "
        << (metrics_.uploadThroughputMbps >= 100.0 ? "✓ PASS" : "✗ FAIL")
        << "\n";
  } else {
    oss << "Upload Performance: No data\n";
  }

  oss << "\n";

  // Download metrics
  if (metrics_.downloadBytes > 0) {
    auto downloadDuration =
        std::chrono::duration_cast<std::chrono::milliseconds>(
            metrics_.downloadEndTime - metrics_.downloadStartTime);

    oss << "Download Performance:\n";
    oss << "  Bytes transferred: " << formatBytes(metrics_.downloadBytes)
        << "\n";
    oss << "  Duration: " << downloadDuration.count() << " ms\n";
    oss << "  Throughput: " << metrics_.downloadThroughputMbps << " Mbps\n";
    oss << "  Target: >200 Mbps "
        << (metrics_.downloadThroughputMbps >= 200.0 ? "✓ PASS" : "✗ FAIL")
        << "\n";
  } else {
    oss << "Download Performance: No data\n";
  }

  oss << "\n";

  // Overall summary
  if (metrics_.uploadBytes > 0 && metrics_.downloadBytes > 0) {
    size_t totalBytes = metrics_.uploadBytes + metrics_.downloadBytes;
    oss << "Overall Summary:\n";
    oss << "  Total bytes transferred: " << formatBytes(totalBytes) << "\n";

    bool uploadPass = metrics_.uploadThroughputMbps >= 100.0;
    bool downloadPass = metrics_.downloadThroughputMbps >= 200.0;
    oss << "  Performance targets: "
        << (uploadPass && downloadPass ? "✓ ALL PASS" : "✗ SOME FAIL") << "\n";
  }

  oss << "========================\n";

  return oss.str();
}

void PerformanceMonitor::logMetricsToConsole() const {
  std::string report = generateReport();
  spdlog::info("Performance Metrics:\n{}", report);
}

void PerformanceMonitor::logMetricsToFile(const std::string &filePath) const {
  try {
    std::ofstream file(filePath, std::ios::app);
    if (file.is_open()) {
      auto now = std::chrono::system_clock::now();
      auto time_t = std::chrono::system_clock::to_time_t(now);

      file << "=== Performance Log Entry ===\n";
      file << "Timestamp: "
           << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S")
           << "\n";
      file << generateReport() << "\n";

      spdlog::debug("Performance metrics logged to file: {}", filePath);
    } else {
      spdlog::error("Failed to open performance log file: {}", filePath);
    }
  } catch (const std::exception &e) {
    spdlog::error("Exception while logging performance metrics to file: {}",
                  e.what());
  }
}

bool PerformanceMonitor::meetsPerformanceTargets() const {
  bool uploadTarget =
      (metrics_.uploadBytes == 0) || (metrics_.uploadThroughputMbps >= 100.0);
  bool downloadTarget = (metrics_.downloadBytes == 0) ||
                        (metrics_.downloadThroughputMbps >= 200.0);
  return uploadTarget && downloadTarget;
}

double PerformanceMonitor::calculateThroughputMbps(
    size_t bytes, std::chrono::steady_clock::time_point start,
    std::chrono::steady_clock::time_point end) const {

  auto duration =
      std::chrono::duration_cast<std::chrono::microseconds>(end - start);
  if (duration.count() == 0)
    return 0.0;

  double seconds =
      duration.count() / 1000000.0; // Convert microseconds to seconds
  double bits = bytes * 8.0;
  double mbps = (bits / seconds) / 1000000.0; // Convert to Megabits per second
  return mbps;
}

std::string PerformanceMonitor::formatBytes(size_t bytes) const {
  std::ostringstream oss;
  oss << std::fixed << std::setprecision(2);

  if (bytes >= 1024 * 1024 * 1024) {
    oss << (bytes / (1024.0 * 1024.0 * 1024.0)) << " GB";
  } else if (bytes >= 1024 * 1024) {
    oss << (bytes / (1024.0 * 1024.0)) << " MB";
  } else if (bytes >= 1024) {
    oss << (bytes / 1024.0) << " KB";
  } else {
    oss << bytes << " bytes";
  }

  return oss.str();
}

} // namespace audio_stream
