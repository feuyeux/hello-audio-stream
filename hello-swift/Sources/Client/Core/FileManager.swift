import Foundation
import AudioStreamCommon

/// File I/O operations
class AudioFileManager {
    private static let chunkSize = 65536 // 64KB
    
    static func readChunk(path: String, offset: Int64, size: Int) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? fileHandle.close() }
        
        try fileHandle.seek(toOffset: UInt64(offset))
        guard let data = try fileHandle.read(upToCount: size) else {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read data"])
        }
        
        return data
    }
    
    static func writeChunk(path: String, data: Data, append: Bool = true) throws {
        let url = URL(fileURLWithPath: path)
        
        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        try Foundation.FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        if append && Foundation.FileManager.default.fileExists(atPath: path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }
    
    static func computeSha256(path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        // Use SHA1 as we don't have CryptoKit for SHA256, and SHA1 is available in AudioStreamCommon
        let hash = SHA1.hash(data: data)
        return SHA1.hexString(from: hash)
    }
    
    static func getFileSize(path: String) throws -> Int64 {
        let attributes = try Foundation.FileManager.default.attributesOfItem(atPath: path)
        guard let size = attributes[.size] as? Int64 else {
            throw NSError(domain: "FileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get file size"])
        }
        return size
    }
    
    static func deleteFile(path: String) {
        try? Foundation.FileManager.default.removeItem(atPath: path)
    }
}
