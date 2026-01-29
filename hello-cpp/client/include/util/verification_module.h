#ifndef AUDIO_STREAM_VERIFICATION_MODULE_H
#define AUDIO_STREAM_VERIFICATION_MODULE_H

#include "../../include/common_types.h"
#include <string>

namespace audio_stream {

/**
 * Verification module for file integrity checking
 * Computes checksums and compares files
 */
class VerificationModule {
public:
  VerificationModule() = default;

  // Checksum computation
  std::string computeMD5(const std::string &filePath);
  std::string computeSHA1(const std::string &filePath);
  std::string computeSHA256(const std::string &filePath);

  // File comparison
  bool compareFiles(const std::string &file1, const std::string &file2);
  VerificationReport generateReport(const std::string &originalFile,
                                    const std::string &downloadedFile);

private:
  enum class HashAlgorithm { MD5, SHA1, SHA256 };

  std::string computeChecksum(const std::string &filePath,
                              HashAlgorithm algorithm);
};

} // namespace audio_stream

#endif // AUDIO_STREAM_VERIFICATION_MODULE_H
