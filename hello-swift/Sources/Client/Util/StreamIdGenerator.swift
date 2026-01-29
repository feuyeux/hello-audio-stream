import Foundation

/// Stream ID generator for creating unique stream identifiers
class StreamIdGenerator {
    /// Generate a unique stream ID with timestamp and random component
    static func generate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let random = String(format: "%08x", Int.random(in: 0...0xFFFFFFFF))
        return "stream-\(timestamp)-\(random)"
    }
    
    /// Validate stream ID format
    static func validate(_ streamId: String) -> Bool {
        return streamId.hasPrefix("stream-") && streamId.count > 8
    }
}
