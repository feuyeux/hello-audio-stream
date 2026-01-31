import Foundation
import CryptoKit
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        if append && FileManager.default.fileExists(atPath: path) {
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
        let sha256 = SHA256.hash(data: data)
        return sha256.map { String(format: "%02x", $0) }.joined()
    }
    
    static func getFileSize(path: String) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let size = attributes[.size] as? Int64 else {
            throw NSError(domain: "FileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get file size"])
        }
        return size
    }
    
    static func deleteFile(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
