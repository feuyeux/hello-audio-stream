
//
//  MemoryMappedCache.swift
//  Audio Stream Server
//
//  Memory-mapped cache for efficient file I/O.
//  Provides write, read, resize, and finalize operations.
//  Matches Python MmapCache functionality.
//  Windows Implementation using WinSDK.
//

import AudioStreamCommon
import Foundation
#if os(Windows)
import WinSDK
#endif

// Configuration constants - follows unified mmap implementation specification v2.0.0
// These are available on all platforms, but only used by Windows implementation here.
let DEFAULT_PAGE_SIZE: Int64 = 64 * 1024 * 1024 // 64MB
let MAX_CACHE_SIZE: Int64 = 8 * 1024 * 1024 * 1024 // 8GB
let SEGMENT_SIZE: Int64 = 1 * 1024 * 1024 * 1024 // 1GB per segment
let BATCH_OPERATION_LIMIT: Int = 1000  // Max batch operations

#if os(Windows)

// Windows Implementation using FileHandle (Fallback for stability)
class MemoryMappedCache: @unchecked Sendable {
    let path: String
    private var fileHandle: FileHandle?
    private var size: Int64 = 0
    private var _isOpen = false
    private let rwLock = NSLock()

    /// Create a new MemoryMappedCache.
    init(path: String) {
        self.path = path
    }
    
    deinit {
        close()
    }

    /// Create a new file.
    func create(filePath: String, initialSize: Int64 = 0) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        if !FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil) {
            Logger.error("Failed to create file: \(filePath)")
            return false
        }
        
        guard let handle = FileHandle(forUpdatingAtPath: filePath) else {
            Logger.error("Failed to open file handle for: \(filePath)")
            return false
        }
        
        self.fileHandle = handle
        self._isOpen = true
        
        if initialSize > 0 {
            if !resizeInternal(newSize: initialSize) {
                return false
            }
        }
        
        self.size = initialSize
        Logger.info("Created file: \(filePath) with size: \(initialSize)")
        return true
    }

    /// Open an existing file.
    func open(filePath: String) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("File does not exist: \(filePath)")
            return false
        }
        
        guard let handle = FileHandle(forUpdatingAtPath: filePath) else {
             Logger.error("Failed to open file handle for: \(filePath)")
             return false
        }
        
        self.fileHandle = handle
        self.size = Int64(handle.seekToEndOfFile())
        self._isOpen = true
        
        Logger.info("Opened file: \(filePath) with size: \(self.size)")
        return true
    }

    /// Close the file.
    func close() {
        rwLock.lock()
        defer { rwLock.unlock() }

        if _isOpen {
            try? fileHandle?.close()
            fileHandle = nil
            _isOpen = false
        }
    }

    /// Write data to the file.
    func write(offset: Int64, data: Data) -> Int {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !_isOpen || fileHandle == nil {
            if !open(filePath: path) { // Try to re-open
                 // If doesn't exist, create
                 if !create(filePath: path, initialSize: offset + Int64(data.count)) {
                     return 0
                 }
            }
        }
        
        guard let handle = fileHandle else { return 0 }

        let requiredSize = offset + Int64(data.count)
        if requiredSize > size {
            // Implicit resize by writing beyond end? 
            // FileHandle auto-extends on write, but good to track size
        }

        do {
            try handle.seek(toOffset: UInt64(offset))
            try handle.write(contentsOf: data)
            
            // Update size if we extended it
            if requiredSize > size {
                size = requiredSize
            }
            return data.count
        } catch {
            Logger.error("Error writing to file: \(error)")
            return 0
        }
    }

    /// Read data from the file.
    func read(offset: Int64, length: Int) -> Data {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !_isOpen || fileHandle == nil {
             if !open(filePath: path) {
                 return Data()
             }
        }
        
        guard let handle = fileHandle else { return Data() }
        
        if offset >= size {
            return Data()
        }

        do {
            try handle.seek(toOffset: UInt64(offset))
            // Read up to 'length' bytes
            // Note: readData(ofLength:) might return fewer bytes if EOF is reached
            let data = try handle.read(upToCount: length)
            Logger.debug("Read \(data?.count ?? 0) bytes from offset \(offset) (requested \(length))")
            return data ?? Data()
        } catch {
            Logger.error("Error reading from file: \(error)")
            return Data()
        }
    }
    
    /// Get the size of the file.
    func getSize() -> Int64 {
        return size
    }
    
    /// Get the path of the file.
    func getPath() -> String {
        return path
    }

    /// Check if the file is open.
    func isOpen() -> Bool {
        return _isOpen
    }

    /// Resize the file to a new size.
    func resize(newSize: Int64) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        return resizeInternal(newSize: newSize)
    }
    
    /// Resize the file to a new size (internal version without lock).
    private func resizeInternal(newSize: Int64) -> Bool {
        guard let handle = fileHandle else { return false }
        
        do {
            try handle.truncate(atOffset: UInt64(newSize))
            self.size = newSize
            Logger.info("Resized file \(path) to \(newSize) bytes")
            return true
        } catch {
            Logger.error("Error resizing file: \(error)")
            return false
        }
    }

    /// Flush all data to disk.
    func flush() -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        
        guard let handle = fileHandle else { return false }
        
        do {
            try handle.synchronize() // Flush to disk
            Logger.debug("Flushed file: \(path)")
            return true
        } catch {
            Logger.error("Error flushing file: \(error)")
            return false
        }
    }

    /// Finalize the file to its final size.
    func finalize(finalSize: Int64) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard _isOpen else {
            Logger.error("File not open for finalization: \(path)")
            return false
        }

        return resizeInternal(newSize: finalSize)
    }
}

#else

// NON-WINDOWS file-backed implementation
class MemoryMappedCache: @unchecked Sendable {
    let path: String
    private var fileHandle: FileHandle?
    private var size: Int64 = 0
    private var _isOpen = false
    private let rwLock = NSLock()

    init(path: String) {
        self.path = path
    }

    deinit {
        close()
    }

    func create(filePath: String, initialSize: Int64 = 0) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        guard FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil) else {
            Logger.error("Failed to create file: \(filePath)")
            return false
        }

        guard let handle = FileHandle(forUpdatingAtPath: filePath) else {
            Logger.error("Failed to open file handle for: \(filePath)")
            return false
        }

        self.fileHandle = handle
        self._isOpen = true

        if initialSize > 0 && !resizeInternal(newSize: initialSize) {
            return false
        }

        self.size = initialSize
        Logger.info("Created file: \(filePath) with size: \(initialSize)")
        return true
    }

    func open(filePath: String) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("File does not exist: \(filePath)")
            return false
        }

        guard let handle = FileHandle(forUpdatingAtPath: filePath) else {
            Logger.error("Failed to open file handle for: \(filePath)")
            return false
        }

        self.fileHandle = handle
        self.size = Int64(handle.seekToEndOfFile())
        self._isOpen = true
        Logger.info("Opened file: \(filePath) with size: \(self.size)")
        return true
    }

    func close() {
        rwLock.lock()
        defer { rwLock.unlock() }

        if _isOpen {
            try? fileHandle?.close()
            fileHandle = nil
            _isOpen = false
        }
    }

    func write(offset: Int64, data: Data) -> Int {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !_isOpen || fileHandle == nil {
            if !open(filePath: path) {
                if !create(filePath: path, initialSize: offset + Int64(data.count)) {
                    return 0
                }
            }
        }

        guard let handle = fileHandle else { return 0 }
        let requiredSize = offset + Int64(data.count)

        do {
            try handle.seek(toOffset: UInt64(offset))
            try handle.write(contentsOf: data)
            if requiredSize > size {
                size = requiredSize
            }
            return data.count
        } catch {
            Logger.error("Error writing to file: \(error)")
            return 0
        }
    }

    func read(offset: Int64, length: Int) -> Data {
        rwLock.lock()
        defer { rwLock.unlock() }

        if !_isOpen || fileHandle == nil {
            if !open(filePath: path) {
                return Data()
            }
        }

        guard let handle = fileHandle else { return Data() }
        if offset >= size { return Data() }

        do {
            try handle.seek(toOffset: UInt64(offset))
            return try handle.read(upToCount: length) ?? Data()
        } catch {
            Logger.error("Error reading from file: \(error)")
            return Data()
        }
    }

    func getSize() -> Int64 {
        return size
    }

    func getPath() -> String {
        return path
    }

    func isOpen() -> Bool {
        return _isOpen
    }

    func resize(newSize: Int64) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }
        return resizeInternal(newSize: newSize)
    }

    private func resizeInternal(newSize: Int64) -> Bool {
        guard let handle = fileHandle else { return false }
        do {
            try handle.truncate(atOffset: UInt64(newSize))
            self.size = newSize
            Logger.info("Resized file \(path) to \(newSize) bytes")
            return true
        } catch {
            Logger.error("Error resizing file: \(error)")
            return false
        }
    }

    func flush() -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard let handle = fileHandle else { return false }
        do {
            try handle.synchronize()
            return true
        } catch {
            Logger.error("Error flushing file: \(error)")
            return false
        }
    }

    func finalize(finalSize: Int64) -> Bool {
        rwLock.lock()
        defer { rwLock.unlock() }

        guard _isOpen else {
            Logger.error("File not open for finalization: \(path)")
            return false
        }
        return resizeInternal(newSize: finalSize)
    }
}

#endif
