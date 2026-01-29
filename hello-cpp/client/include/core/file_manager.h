#ifndef AUDIO_STREAM_FILE_MANAGER_H
#define AUDIO_STREAM_FILE_MANAGER_H

#include "../../include/common_types.h"
#include <cstdint>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

namespace audio_stream {

/**
 * File manager for reading and writing audio files
 * Handles file I/O operations with proper resource management
 */
class FileManager {
public:
  FileManager() = default;
  virtual ~FileManager();

  // File reading
  virtual bool openForReading(const std::string &filePath);
  virtual size_t read(std::vector<uint8_t> &buffer, size_t size);
  virtual size_t
  readChunk(std::vector<uint8_t> &chunk); // Read next chunk (64KB)
  virtual bool hasMoreData() const;
  virtual size_t getFileSize() const;
  virtual void closeReader();

  // File writing
  virtual bool openForWriting(const std::string &filePath);
  virtual bool write(const std::vector<uint8_t> &data);
  virtual void closeWriter();

  // Utility
  virtual bool fileExists(const std::string &filePath) const;
  virtual std::string getFilePath() const;

private:
  std::string filePath_;
  size_t fileSize_ = 0;
  std::unique_ptr<std::ifstream> inputFile_;
  std::unique_ptr<std::ofstream> outputFile_;
};

} // namespace audio_stream

#endif // AUDIO_STREAM_FILE_MANAGER_H
