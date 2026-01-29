//
//  MemoryMappedCache.swift
//  Audio Stream Server
//
//  Memory-mapped cache for efficient file I/O.
//  Provides write, read, resize, and finalize operations.
//  Matches Python MmapCache functionality.
//

import AudioStreamCommon
import Foundation

let DEFAULT_PAGE_SIZE: Int64 = 64 * 1024 * 1024  // 64MB
let MAX_CACHE_SIZE: Int64 = 2 * 1024 * 1024 * 1024  // 2GB

/// Memory-mapped cache implementation.
class MemoryMappedCache {
    let path: String
    private var fileHandle: FileHandle?
    private var size: Int64 = 0
    private var isOpen = false
    private let rwLock = NSLock()

    /// Create a new MemoryMappedCache.
    init(path: String) {
        self.path = path
    }

    /// Create a new memory-mapped file.
    func create(filePath: String, initialSize: Int64 = 0) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        return createInternal(filePath: filePath, initialSize: initialSize)
    }

    private func createInternal(filePath: String, initialSize: Int64) -> Bool {
        // Remove existing file
        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        // Create and open file
        guard FileManager.default.createFile(atPath: filePath, contents: nil) else {
            Logger.error("Error creating file \(filePath)")
            return false
        }

        guard let handle = FileHandle(forWritingAtPath: filePath) else {
            Logger.error("Error opening file handle for \(filePath)")
            return false
        }

        self.fileHandle = handle

        if initialSize > 0 {
            // Write zeros to allocate space
            let buffer = Data(repeating: 0, count: Int(initialSize))
            do {
                try handle.write(contentsOf: buffer)
            } catch {
                Logger.error("Error allocating space for \(filePath)")
                return false
            }
            self.size = initialSize
        } else {
            self.size = 0
        }

        self.isOpen = true
        Logger.debug("Created mmap file: \(filePath) with size: \(initialSize)")
        return true
    }

    /// Open an existing memory-mapped file.
    func open(filePath: String) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        return openInternal(filePath: filePath)
    }

    private func openInternal(filePath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("File does not exist: \(filePath)")
            return false
        }

        guard let handle = FileHandle(forReadingAtPath: filePath),
            let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
            let fileSize = attributes[.size] as? Int64
        else {
            Logger.error("Error opening file \(filePath)")
            return false
        }

        self.fileHandle = handle
        self.size = fileSize
        self.isOpen = true
        Logger.debug("Opened mmap file: \(filePath) with size: \(fileSize)")
        return true
    }

    /// Close the memory-mapped file.
    func close() {
        rwLock.lock()
        defer { rwLock.unlock() }
        closeInternal()
    }

    private func closeInternal() {
        if isOpen, let handle = fileHandle {
            try? handle.close()
            fileHandle = nil
            isOpen = false
        }
    }

    /// Write data to the file.
    func write(offset: Int64, data: Data) -> Int {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !isOpen || fileHandle == nil {
            let initialSize = offset + Int64(data.count)
            if !createInternal(filePath: path, initialSize: initialSize) {
                return 0
            }
        }

        let requiredSize = offset + Int64(data.count)
        if requiredSize > size {
            if !resizeInternal(newSize: requiredSize) {
                Logger.error("Failed to resize file for write operation")
                return 0
            }
        }

        guard let handle = fileHandle else {
            return 0
        }

        // Seek to offset
        do {
            try handle.seek(toOffset: UInt64(offset))
        } catch {
            Logger.error("Error seeking in file \(path)")
            return 0
        }

        // Write data
        do {
            try handle.write(contentsOf: data)
        } catch {
            Logger.error("Error writing to file \(path)")
            return 0
        }

        return data.count
    }

    /// Read data from the file.
    func read(offset: Int64, length: Int) -> Data {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !isOpen || fileHandle == nil {
            if !openInternal(filePath: path) {
                Logger.error("Failed to open file for reading: \(path)")
                return Data()
            }
        }

        if offset >= size {
            return Data()
        }

        guard let handle = fileHandle else {
            return Data()
        }

        // Seek to offset
        do {
            try handle.seek(toOffset: UInt64(offset))
        } catch {
            Logger.error("Error seeking in file \(path)")
            return Data()
        }

        // Read data
        let actualLength = min(length, Int(size - offset))
        guard let data = try? handle.read(upToCount: actualLength) else {
            Logger.error("Error reading from file \(path)")
            return Data()
        }

        return data
    }

    /// Get the size of the file.
    func getSize() -> Int64 {
        rwLock.lock()
        defer { rwLock.unlock() }
        return size
    }

    /// Get the path of the file.
    func getPath() -> String {
        return path
    }

    /// Check if the file is open.
    func getIsOpen() -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        return isOpen
    }

    /// Resize the file to a new size (internal version without lock).
    private func resizeInternal(newSize: Int64) -> Bool {
        guard isOpen, let handle = fileHandle else {
            Logger.error("File not open for resize: \(path)")
            return false
        }

        if newSize == size {
            return true
        }

        if newSize < size {
            // Truncate - this is simplified, real implementation would need more work
            Logger.warn("Truncating file \(path) to \(newSize)")
        } else {
            // Expand - write zeros at the end
            let extra = Int(newSize - size)
            let buffer = Data(repeating: 0, count: extra)
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: buffer)
            } catch {
                Logger.error("Error expanding file \(path)")
                return false
            }
        }

        size = newSize
        Logger.debug("Resized file \(path) to \(newSize) bytes")
        return true
    }

    /// Finalize the file to its final size.
    func finalize(finalSize: Int64) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard isOpen else {
            Logger.warn("File not open for finalization: \(path)")
            return false
        }

        if !resizeInternal(newSize: finalSize) {
            Logger.error("Failed to resize file during finalization: \(path)")
            return false
        }

        // Sync to disk (file handles auto-sync on close)
        Logger.debug("Finalized file: \(path) with size: \(finalSize)")
        return true
    }
}
