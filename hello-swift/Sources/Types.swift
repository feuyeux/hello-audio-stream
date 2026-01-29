import Foundation

/// WebSocket message types enum
/// All type values are uppercase as per protocol specification
public enum MessageType: String, Codable, CaseIterable {
    case START = "START"
    case STARTED = "STARTED"
    case STOP = "STOP"
    case STOPPED = "STOPPED"
    case GET = "GET"
    case ERROR = "ERROR"
    case CONNECTED = "CONNECTED"

    /// Parse string to MessageType enum
    /// Case-insensitive comparison for backward compatibility
    public static func fromString(_ value: String?) -> MessageType? {
        guard let value = value else { return nil }
        return MessageType.allCases.first {
            $0.rawValue.caseInsensitiveCompare(value) == .orderedSame
        }
    }
}

/// Configuration for the audio client
public struct Config {
    public let inputPath: String
    public let outputPath: String
    public let serverUri: String
    public let verbose: Bool

    public init(inputPath: String, outputPath: String, serverUri: String, verbose: Bool) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.serverUri = serverUri
        self.verbose = verbose
    }
}

/// WebSocket message for communication
public struct WebSocketMessage: Codable {
    public let type: String
    public let streamId: String?
    public let offset: Int64?
    public let length: Int?
    public let message: String?

    public init(type: String, streamId: String?, offset: Int64?, length: Int?, message: String?) {
        self.type = type
        self.streamId = streamId
        self.offset = offset
        self.length = length
        self.message = message
    }
}

/// Verification result
public struct VerificationResult {
    public let passed: Bool
    public let originalSize: Int64
    public let downloadedSize: Int64
    public let originalChecksum: String
    public let downloadedChecksum: String

    public init(
        passed: Bool, originalSize: Int64, downloadedSize: Int64, originalChecksum: String,
        downloadedChecksum: String
    ) {
        self.passed = passed
        self.originalSize = originalSize
        self.downloadedSize = downloadedSize
        self.originalChecksum = originalChecksum
        self.downloadedChecksum = downloadedChecksum
    }
}

/// Performance report
public struct PerformanceReport {
    public let uploadDurationMs: Int64
    public let uploadThroughputMbps: Double
    public let downloadDurationMs: Int64
    public let downloadThroughputMbps: Double
    public let totalDurationMs: Int64
    public let averageThroughputMbps: Double

    public init(
        uploadDurationMs: Int64, uploadThroughputMbps: Double, downloadDurationMs: Int64,
        downloadThroughputMbps: Double, totalDurationMs: Int64, averageThroughputMbps: Double
    ) {
        self.uploadDurationMs = uploadDurationMs
        self.uploadThroughputMbps = uploadThroughputMbps
        self.downloadDurationMs = downloadDurationMs
        self.downloadThroughputMbps = downloadThroughputMbps
        self.totalDurationMs = totalDurationMs
        self.averageThroughputMbps = averageThroughputMbps
    }
}
