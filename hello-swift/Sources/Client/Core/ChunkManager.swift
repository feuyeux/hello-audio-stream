import Foundation

/// Chunk manager for handling file chunking operations
class ChunkManager {
    static let defaultChunkSize = 8192 // 8KB to avoid WebSocket frame fragmentation
    
    /// Calculate the number of chunks needed for a file
    static func calculateChunkCount(fileSize: Int64, chunkSize: Int = defaultChunkSize) -> Int {
        return Int((fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))
    }
    
    /// Get the size of a specific chunk
    static func getChunkSize(fileSize: Int64, offset: Int64, defaultSize: Int = defaultChunkSize) -> Int {
        return min(defaultSize, Int(fileSize - offset))
    }
    
    /// Validate chunk parameters
    static func validateChunk(fileSize: Int64, offset: Int64, chunkSize: Int) throws {
        guard offset >= 0 && offset < fileSize else {
            throw NSError(domain: "ChunkManager", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid offset: \(offset)"])
        }
        guard chunkSize > 0 else {
            throw NSError(domain: "ChunkManager", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid chunk size: \(chunkSize)"])
        }
    }
}
