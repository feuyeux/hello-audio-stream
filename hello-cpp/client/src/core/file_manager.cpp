#include "core/file_manager.h"
#include <filesystem>
#include <spdlog/spdlog.h>

namespace audio_stream {

FileManager::~FileManager() {
  closeReader();
  closeWriter();
}

bool FileManager::openForReading(const std::string &filePath) {
  try {
    spdlog::debug("Opening file for reading: {}", filePath);

    // Check if file exists
    if (!std::filesystem::exists(filePath)) {
      spdlog::error("File does not exist: {}", filePath);
      return false;
    }

    // Get file size
    std::error_code ec;
    fileSize_ = std::filesystem::file_size(filePath, ec);
    if (ec) {
      spdlog::error("Failed to get file size for {}: {}", filePath,
                    ec.message());
      return false;
    }

    // Open file for binary reading
    inputFile_ = std::make_unique<std::ifstream>(filePath, std::ios::binary);
    if (!inputFile_->is_open()) {
      spdlog::error("Failed to open file for reading: {}", filePath);
      return false;
    }

    filePath_ = filePath;
    spdlog::info("Successfully opened file for reading: {} (size: {} bytes)",
                 filePath, fileSize_);
    return true;

  } catch (const std::exception &e) {
    spdlog::error("Exception while opening file {}: {}", filePath, e.what());
    return false;
  }
}

size_t FileManager::read(std::vector<uint8_t> &buffer, size_t size) {
  if (!inputFile_ || !inputFile_->is_open()) {
    spdlog::error("File not open for reading");
    return 0;
  }

  try {
    // Resize buffer to requested size
    buffer.resize(size);

    // Read data from file
    inputFile_->read(reinterpret_cast<char *>(buffer.data()), size);

    // Get actual bytes read
    size_t bytesRead = static_cast<size_t>(inputFile_->gcount());

    // Resize buffer to actual bytes read
    buffer.resize(bytesRead);

    spdlog::debug("Read {} bytes from file", bytesRead);
    return bytesRead;

  } catch (const std::exception &e) {
    spdlog::error("Exception while reading file: {}", e.what());
    return 0;
  }
}

size_t FileManager::readChunk(std::vector<uint8_t> &chunk) {
  return read(chunk, CHUNK_SIZE);
}

bool FileManager::hasMoreData() const {
  if (!inputFile_ || !inputFile_->is_open()) {
    return false;
  }

  // Check if we're at end of file or if stream is in bad state
  return inputFile_->good() && !inputFile_->eof();
}

size_t FileManager::getFileSize() const { return fileSize_; }

void FileManager::closeReader() {
  if (inputFile_) {
    inputFile_->close();
    inputFile_.reset();
  }
}

bool FileManager::openForWriting(const std::string &filePath) {
  try {
    spdlog::debug("Opening file for writing: {}", filePath);

    // Create directory if it doesn't exist
    std::filesystem::path path(filePath);
    if (path.has_parent_path()) {
      std::filesystem::create_directories(path.parent_path());
    }

    // Open file for binary writing
    outputFile_ = std::make_unique<std::ofstream>(
        filePath, std::ios::binary | std::ios::trunc);
    if (!outputFile_->is_open()) {
      spdlog::error("Failed to open file for writing: {}", filePath);
      return false;
    }

    filePath_ = filePath;
    spdlog::info("Successfully opened file for writing: {}", filePath);
    return true;

  } catch (const std::exception &e) {
    spdlog::error("Exception while opening file for writing {}: {}", filePath,
                  e.what());
    return false;
  }
}

bool FileManager::write(const std::vector<uint8_t> &data) {
  if (!outputFile_ || !outputFile_->is_open()) {
    spdlog::error("File not open for writing");
    return false;
  }

  try {
    // Write data to file
    outputFile_->write(reinterpret_cast<const char *>(data.data()),
                       data.size());

    // Check for write errors
    if (outputFile_->fail()) {
      spdlog::error("Failed to write {} bytes to file", data.size());
      return false;
    }

    // Flush to ensure data is written
    outputFile_->flush();

    spdlog::debug("Successfully wrote {} bytes to file", data.size());
    return true;

  } catch (const std::exception &e) {
    spdlog::error("Exception while writing to file: {}", e.what());
    return false;
  }
}

void FileManager::closeWriter() {
  if (outputFile_) {
    outputFile_->close();
    outputFile_.reset();
  }
}

bool FileManager::fileExists(const std::string &filePath) const {
  return std::filesystem::exists(filePath);
}

std::string FileManager::getFilePath() const { return filePath_; }

} // namespace audio_stream
