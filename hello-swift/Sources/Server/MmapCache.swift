import Foundation

/// File-backed cache using FileHandle for cross-platform compatibility.
class MmapCache {
    let path: String
    private var fileHandle: FileHandle?
    private(set) var size: Int64 = 0
    private let lock = NSLock()

    init(path: String) {
        self.path = path
    }

    deinit { close() }

    /// Create a new cache file.
    func create(initialSize: Int64 = 0) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default

        // Ensure parent directory exists
        let dir = (path as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
        guard fm.createFile(atPath: path, contents: nil) else { return false }
        guard let handle = FileHandle(forUpdatingAtPath: path) else { return false }

        fileHandle = handle
        if initialSize > 0 {
            handle.seekToEndOfFile()
            handle.write(Data(count: Int(initialSize)))
        }
        size = initialSize
        return true
    }

    /// Write data at the given offset, auto-resizing if needed.
    func write(offset: Int64, data: Data) -> Int {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = fileHandle else { return 0 }
        let needed = offset + Int64(data.count)
        if needed > size {
            resize(needed * 2)
        }
        handle.seek(toFileOffset: UInt64(offset))
        handle.write(data)
        return data.count
    }

    /// Read data from the given offset.
    func read(offset: Int64, length: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = fileHandle else { return Data() }
        handle.seek(toFileOffset: UInt64(offset))
        return handle.readData(ofLength: length)
    }

    /// Truncate file to final size after upload completes.
    func finalize(finalSize: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = fileHandle else { return false }
        handle.truncateFile(atOffset: UInt64(finalSize))
        size = finalSize
        return true
    }

    /// Close the file handle.
    func close() {
        lock.lock()
        defer { lock.unlock() }

        try? fileHandle?.close()
        fileHandle = nil
    }

    private func resize(_ newSize: Int64) {
        guard let handle = fileHandle else { return }
        let pos = handle.offsetInFile
        handle.seekToEndOfFile()
        let grow = newSize - size
        if grow > 0 {
            handle.write(Data(count: Int(grow)))
        }
        size = newSize
        handle.seek(toFileOffset: pos)
    }
}
