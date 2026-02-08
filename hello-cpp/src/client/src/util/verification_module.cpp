#include "util/verification_module.h"
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <spdlog/spdlog.h>
#include <sstream>

// Third-party library websocketpp has pointer arithmetic warning in md5.hpp
// This is a known issue in the library and cannot be fixed without modifying
// third-party code Issue: https://github.com/zaphoyd/websocketpp/issues/1006
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnull-pointer-subtraction"
#include <websocketpp/common/md5.hpp>
#include <websocketpp/sha1/sha1.hpp>
#pragma GCC diagnostic pop

#ifndef WEBSOCKETPP_NO_TLS
#include <openssl/sha.h>
#endif

namespace audio_stream {

std::string VerificationModule::computeMD5(const std::string &filePath) {
  return computeChecksum(filePath, HashAlgorithm::MD5);
}

std::string VerificationModule::computeSHA1(const std::string &filePath) {
  return computeChecksum(filePath, HashAlgorithm::SHA1);
}

std::string VerificationModule::computeSHA256(const std::string &filePath) {
  return computeChecksum(filePath, HashAlgorithm::SHA256);
}

std::string VerificationModule::computeChecksum(const std::string &filePath,
                                                HashAlgorithm algorithm) {
  const char *algorithmName = (algorithm == HashAlgorithm::MD5)    ? "MD5"
                              : (algorithm == HashAlgorithm::SHA1) ? "SHA1"
                                                                   : "SHA256";

  spdlog::debug("Computing {} checksum for: {}", algorithmName, filePath);

  try {
    // Check if file exists
    if (!std::filesystem::exists(filePath)) {
      spdlog::error("File does not exist: {}", filePath);
      return "";
    }

    // Open file for binary reading
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) {
      spdlog::error("Failed to open file: {}", filePath);
      return "";
    }

    if (algorithm == HashAlgorithm::SHA256) {
#ifndef WEBSOCKETPP_NO_TLS
      // Use OpenSSL SHA256
      file.seekg(0, std::ios::end);
      size_t fileSize = file.tellg();
      file.seekg(0, std::ios::beg);

      std::vector<char> buffer(fileSize);
      file.read(buffer.data(), fileSize);

      // Calculate SHA256
      unsigned char hash[SHA256_DIGEST_LENGTH];
      SHA256(reinterpret_cast<const unsigned char *>(buffer.data()), fileSize,
             hash);

      // Convert to hex string
      std::stringstream ss;
      for (int i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0')
           << static_cast<int>(hash[i]);
      }

      std::string result = ss.str();
      spdlog::debug("SHA256 checksum computed: {}", result);
      return result;
#else
      spdlog::error("SHA256 not available (OpenSSL not found)");
      return "";
#endif

    } else if (algorithm == HashAlgorithm::SHA1) {
      // Use websocketpp SHA1
      file.seekg(0, std::ios::end);
      size_t fileSize = file.tellg();
      file.seekg(0, std::ios::beg);

      std::vector<char> buffer(fileSize);
      file.read(buffer.data(), fileSize);

      // Calculate SHA1
      unsigned char hash[20];
      websocketpp::sha1::calc(buffer.data(), fileSize, hash);

      // Convert to hex string
      std::stringstream ss;
      for (int i = 0; i < 20; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0')
           << static_cast<int>(hash[i]);
      }

      std::string result = ss.str();
      spdlog::debug("SHA1 checksum computed: {}", result);
      return result;

    } else {
      // Use websocketpp MD5
      websocketpp::md5::md5_state_t md5State;
      websocketpp::md5::md5_init(&md5State);

      // Read file in chunks and update hash
      constexpr size_t bufferSize = 8192;
      char buffer[bufferSize];

      while (file.read(buffer, bufferSize) || file.gcount() > 0) {
        websocketpp::md5::md5_append(
            &md5State,
            reinterpret_cast<const websocketpp::md5::md5_byte_t *>(buffer),
            file.gcount());
      }

      // Finalize hash
      websocketpp::md5::md5_byte_t hash[16];
      websocketpp::md5::md5_finish(&md5State, hash);

      // Convert to hex string
      std::stringstream ss;
      for (int i = 0; i < 16; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0')
           << static_cast<int>(hash[i]);
      }

      std::string result = ss.str();
      spdlog::debug("MD5 checksum computed: {}", result);
      return result;
    }

  } catch (const std::exception &e) {
    spdlog::error("Exception while computing checksum for {}: {}", filePath,
                  e.what());
    return "";
  }
}

bool VerificationModule::compareFiles(const std::string &file1,
                                      const std::string &file2) {
  spdlog::debug("Comparing files: {} vs {}", file1, file2);

  try {
    // Check if both files exist
    if (!std::filesystem::exists(file1)) {
      spdlog::error("First file does not exist: {}", file1);
      return false;
    }

    if (!std::filesystem::exists(file2)) {
      spdlog::error("Second file does not exist: {}", file2);
      return false;
    }

    // Compare file sizes first (quick check)
    std::error_code ec1, ec2;
    auto size1 = std::filesystem::file_size(file1, ec1);
    auto size2 = std::filesystem::file_size(file2, ec2);

    if (ec1 || ec2) {
      spdlog::error("Failed to get file sizes: {} ({}), {} ({})", file1,
                    ec1.message(), file2, ec2.message());
      return false;
    }

    if (size1 != size2) {
      spdlog::info("Files have different sizes: {} bytes vs {} bytes", size1,
                   size2);
      return false;
    }

    // Compare checksums for thorough verification
    std::string checksum1 = computeSHA1(file1);
    std::string checksum2 = computeSHA1(file2);

    if (checksum1.empty() || checksum2.empty()) {
      spdlog::error("Failed to compute checksums for comparison");
      return false;
    }

    bool match = (checksum1 == checksum2);
    spdlog::info("File comparison result: {} (checksums: {} vs {})",
                 match ? "MATCH" : "DIFFERENT", checksum1, checksum2);

    return match;

  } catch (const std::exception &e) {
    spdlog::error("Exception while comparing files {} and {}: {}", file1, file2,
                  e.what());
    return false;
  }
}

VerificationReport
VerificationModule::generateReport(const std::string &originalFile,
                                   const std::string &downloadedFile) {
  spdlog::info("Generating verification report for: {} vs {}", originalFile,
               downloadedFile);

  VerificationReport report;
  report.originalFilePath = originalFile;
  report.downloadedFilePath = downloadedFile;

  try {
    // Get file sizes
    if (std::filesystem::exists(originalFile)) {
      std::error_code ec;
      report.originalSize = std::filesystem::file_size(originalFile, ec);
      if (ec) {
        spdlog::error("Failed to get original file size: {}", ec.message());
        report.originalSize = 0;
      }
    } else {
      spdlog::error("Original file does not exist: {}", originalFile);
      report.originalSize = 0;
    }

    if (std::filesystem::exists(downloadedFile)) {
      std::error_code ec;
      report.downloadedSize = std::filesystem::file_size(downloadedFile, ec);
      if (ec) {
        spdlog::error("Failed to get downloaded file size: {}", ec.message());
        report.downloadedSize = 0;
      }
    } else {
      spdlog::error("Downloaded file does not exist: {}", downloadedFile);
      report.downloadedSize = 0;
    }

    // Compare sizes
    report.sizesMatch = (report.originalSize == report.downloadedSize &&
                         report.originalSize > 0 && report.downloadedSize > 0);

    // Compute checksums
    report.originalChecksum = computeSHA1(originalFile);
    report.downloadedChecksum = computeSHA1(downloadedFile);

    // Compare checksums
    report.checksumsMatch =
        (!report.originalChecksum.empty() &&
         !report.downloadedChecksum.empty() &&
         report.originalChecksum == report.downloadedChecksum);

    // Overall verification result
    report.verificationPassed = (report.sizesMatch && report.checksumsMatch);

    // Log results
    spdlog::info("Verification Report:");
    spdlog::info("  Original file: {} ({} bytes, checksum: {})",
                 report.originalFilePath, report.originalSize,
                 report.originalChecksum);
    spdlog::info("  Downloaded file: {} ({} bytes, checksum: {})",
                 report.downloadedFilePath, report.downloadedSize,
                 report.downloadedChecksum);
    spdlog::info("  Sizes match: {}", report.sizesMatch);
    spdlog::info("  Checksums match: {}", report.checksumsMatch);
    spdlog::info("  Verification passed: {}", report.verificationPassed);

  } catch (const std::exception &e) {
    spdlog::error("Exception while generating verification report: {}",
                  e.what());
    report.verificationPassed = false;
  }

  return report;
}

} // namespace audio_stream
