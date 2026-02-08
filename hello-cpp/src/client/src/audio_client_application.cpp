#include "audio_client_application.h"
#include "core/chunk_manager.h"
#include "core/download_manager.h"
#include "core/file_manager.h"
#include "core/upload_manager.h"
#include "core/websocket_client.h"
#include "util/error_handler.h"
#include "util/performance_monitor.h"
#include "util/stream_id_generator.h"
#include "util/verification_module.h"
#include <chrono>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <memory>
#include <spdlog/spdlog.h>
#include <sstream>
#include <string>
#include <thread> // Added for sleep functionality

using namespace audio_stream;

// Configuration structure for client application
struct ClientConfig {
  std::string serverUri;
  std::string inputFile;
  std::string outputFile;
  bool verbose = false;
};

bool parseArguments(int argc, char *argv[], ClientConfig &config) {
  // Set default values
  config.serverUri = "ws://localhost:8080/audio";
  config.inputFile = "";

  // Generate default output file name with timestamp
  auto now = std::chrono::system_clock::now();
  auto time_t = std::chrono::system_clock::to_time_t(now);
  std::stringstream ss;
  ss << std::put_time(std::localtime(&time_t), "%Y%m%d-%H%M%S");
  config.outputFile = "audio/output/output-" + ss.str() + "-test.mp3";

  // Parse optional arguments
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (arg == "--verbose" || arg == "-v") {
      config.verbose = true;
    } else if (arg == "--server" && i + 1 < argc) {
      config.serverUri = argv[++i];
    } else if (arg == "--input" && i + 1 < argc) {
      config.inputFile = argv[++i];
    } else if (arg == "--output" && i + 1 < argc) {
      config.outputFile = argv[++i];
    } else if (arg == "--help" || arg == "-h") {
      spdlog::info("Usage: {} [options]", argv[0]);
      spdlog::info("Options:");
      spdlog::info("  --server <uri>     Server URI (default: "
                   "ws://localhost:8080/audio)");
      spdlog::info("  --input <file>     Input file path (required)");
      spdlog::info(
          "  --output <file>    Output file path (default: auto-generated)");
      spdlog::info("  --verbose, -v      Enable verbose logging");
      spdlog::info("  --help, -h         Show this help message");
      return false;
    }
  }

  return true;
}

bool validateInputs(const ClientConfig &config) {
  // Check if input file is specified
  if (config.inputFile.empty()) {
    spdlog::error("Input file not specified. Use --input <file> option.");
    return false;
  }

  // Check if input file exists
  if (!std::filesystem::exists(config.inputFile)) {
    spdlog::error("Input file does not exist: {}", config.inputFile);
    return false;
  }

  // Check if input file is readable
  std::ifstream testFile(config.inputFile, std::ios::binary);
  if (!testFile.is_open()) {
    spdlog::error("Cannot read input file: {}", config.inputFile);
    return false;
  }
  testFile.close();

  // Check if output directory exists and create if needed
  std::filesystem::path outputPath(config.outputFile);
  std::filesystem::path outputDir = outputPath.parent_path();

  if (!outputDir.empty()) {
    std::error_code ec;
    if (!std::filesystem::exists(outputDir)) {
      if (!std::filesystem::create_directories(outputDir, ec)) {
        spdlog::error("Cannot create output directory: {} - {}",
                      outputDir.string(), ec.message());
        return false;
      }
      spdlog::info("Created output directory: {}", outputDir.string());
    }
  }

  // Validate server URI format
  if (config.serverUri.find("ws://") != 0 &&
      config.serverUri.find("wss://") != 0) {
    spdlog::error("Invalid server URI format. Must start with ws:// or wss://");
    return false;
  }

  return true;
}

int main(int argc, char *argv[]) {
  // Parse command line arguments
  ClientConfig config;
  if (!parseArguments(argc, argv, config)) {
    return 1;
  }

  // Set logging level
  if (config.verbose) {
    spdlog::set_level(spdlog::level::debug);
  } else {
    spdlog::set_level(spdlog::level::info);
  }

  spdlog::info("Audio Stream Cache Client - C++ Implementation");
  spdlog::info("Server URI: {}", config.serverUri);
  spdlog::info("Input file: {}", config.inputFile);
  spdlog::info("Output file: {}", config.outputFile);

  // Validate inputs
  if (!validateInputs(config)) {
    return 1;
  }

  try {
    // Initialize components
    auto client = std::make_shared<WebSocketClient>(config.serverUri);
    auto fileManager = std::make_shared<FileManager>();
    auto chunkManager = std::make_shared<ChunkManager>();
    auto errorHandler = std::make_shared<ErrorHandler>();
    auto uploadManager = std::make_shared<UploadManager>(client, errorHandler);
    auto downloadManager = std::make_shared<DownloadManager>(
        client, fileManager, chunkManager, errorHandler);
    auto verificationModule = std::make_shared<VerificationModule>();
    auto performanceMonitor = std::make_shared<PerformanceMonitor>();

    // Set up error handling callback
    errorHandler->setOnError([](const ErrorHandler::ErrorInfo &error) {
      spdlog::error("Error reported: {} - {}", static_cast<int>(error.type),
                    error.message);
    });

    spdlog::info("=== Connecting to Server ===");

    // Connect to WebSocket server with retry logic
    if (!client->connectWithRetry(DEFAULT_MAX_RETRIES)) {
      errorHandler->reportError(ErrorHandler::ErrorType::CONNECTION_ERROR,
                                "Failed to connect after all retry attempts",
                                config.serverUri, false);
      return 1;
    }
    spdlog::info("Successfully connected to server");

    // Get input file size for progress tracking
    std::error_code ec;
    size_t fileSize = std::filesystem::file_size(config.inputFile, ec);
    if (ec) {
      errorHandler->reportError(ErrorHandler::ErrorType::FILE_IO_ERROR,
                                "Failed to get file size: " + ec.message(),
                                config.inputFile, false);
      return 1;
    }
    spdlog::info("Input file size: {} bytes", fileSize);

    spdlog::info("=== Starting Upload ===");

    // Set message handler for upload phase
    client->setOnMessage([uploadManager](const std::string &message) {
      spdlog::debug("Received server response during upload: {}", message);
      // Forward to upload manager's internal handler
      uploadManager->handleServerResponse(message);
    });

    // Start upload workflow
    performanceMonitor->startUpload();

    std::string uploadedStreamId = uploadManager->uploadFile(config.inputFile);

    performanceMonitor->endUpload(fileSize);

    if (uploadedStreamId.empty()) {
      errorHandler->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                "Upload failed - no stream ID returned",
                                config.inputFile, false);
      return 1;
    }
    spdlog::info("Upload completed successfully with stream ID: {}",
                 uploadedStreamId);

    // Sleep 2 seconds after upload
    spdlog::info("Upload successful, sleeping for 2 seconds...");
    std::this_thread::sleep_for(std::chrono::seconds(2));

    spdlog::info("=== Starting Download ===");

    // Set message handler for download phase
    client->setOnMessage([downloadManager](const std::string &message) {
      downloadManager->handleServerResponse(message);
    });

    // Start download workflow
    performanceMonitor->startDownload();

    bool downloadSuccess =
        downloadManager->downloadFile(uploadedStreamId, config.outputFile);

    performanceMonitor->endDownload(fileSize);

    if (!downloadSuccess) {
      errorHandler->reportError(ErrorHandler::ErrorType::PROTOCOL_ERROR,
                                "Download failed",
                                "Stream ID: " + uploadedStreamId, false);
      return 1;
    }
    spdlog::info("Download completed successfully");

    // Sleep 2 seconds after download
    spdlog::info("Download successful, sleeping for 2 seconds...");
    std::this_thread::sleep_for(std::chrono::seconds(2));

    spdlog::info("=== Verifying File Integrity ===");

    // Verify file integrity
    VerificationReport report =
        verificationModule->generateReport(config.inputFile, config.outputFile);

    if (report.verificationPassed) {
      spdlog::info("✓ File verification PASSED - Files are identical");
    } else {
      errorHandler->reportError(ErrorHandler::ErrorType::VALIDATION_ERROR,
                                "File verification failed - files do not match",
                                "Original: " + config.inputFile +
                                    ", Downloaded: " + config.outputFile,
                                false);
      spdlog::error("✗ File verification FAILED");
      spdlog::error("  Original size: {} bytes, Downloaded size: {} bytes",
                    report.originalSize, report.downloadedSize);
      spdlog::error("  Original checksum: {}", report.originalChecksum);
      spdlog::error("  Downloaded checksum: {}", report.downloadedChecksum);
      return 1;
    }

    spdlog::info("=== Performance Report ===");

    // Generate and display performance report
    performanceMonitor->logMetricsToConsole();

    // Check if performance targets are met
    if (performanceMonitor->meetsPerformanceTargets()) {
      spdlog::info("✓ Performance targets achieved");
    } else {
      spdlog::warn("⚠ Performance targets not met (Upload >100 Mbps, Download "
                   ">200 Mbps)");
    }

    // Disconnect from server
    client->disconnect();
    spdlog::info("Disconnected from server");

    // Report error statistics
    spdlog::info("=== Error Statistics ===");
    spdlog::info(
        "Connection errors: {}",
        errorHandler->getErrorCount(ErrorHandler::ErrorType::CONNECTION_ERROR));
    spdlog::info(
        "File I/O errors: {}",
        errorHandler->getErrorCount(ErrorHandler::ErrorType::FILE_IO_ERROR));
    spdlog::info(
        "Protocol errors: {}",
        errorHandler->getErrorCount(ErrorHandler::ErrorType::PROTOCOL_ERROR));
    spdlog::info(
        "Timeout errors: {}",
        errorHandler->getErrorCount(ErrorHandler::ErrorType::TIMEOUT_ERROR));
    spdlog::info(
        "Validation errors: {}",
        errorHandler->getErrorCount(ErrorHandler::ErrorType::VALIDATION_ERROR));

    spdlog::info("=== Workflow Complete ===");
    spdlog::info("Successfully uploaded, downloaded, and verified file: {}",
                 config.inputFile);

    return 0;

  } catch (const std::exception &e) {
    spdlog::error("Exception occurred: {}", e.what());
    return 1;
  } catch (...) {
    spdlog::error("Unknown exception occurred");
    return 1;
  }
}
