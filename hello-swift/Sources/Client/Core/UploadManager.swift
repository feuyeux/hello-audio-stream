import AudioStreamCommon
import Foundation

/// Upload manager
class UploadManager {
    private static let uploadChunkSize = 8192  // 8KB to avoid WebSocket frame fragmentation

    static func upload(ws: WebSocketClient, filePath: String) async throws -> String {
        let streamId = StreamIdGenerator.generate()
        let fileSize = try AudioFileManager.getFileSize(path: filePath)

        Logger.info("========================================")
        Logger.info("Phase 1: Upload")
        Logger.info("========================================")
        Logger.info("Stream ID: \(streamId)")
        Logger.info("File size: \(fileSize) bytes")

        // Send START message (no response expected, matching Java implementation)
        try await ws.sendText(WebSocketMessage.start(streamId: streamId))
        Logger.info("Sent START message for stream: \(streamId)")

        // Upload file in chunks
        var offset: Int64 = 0
        var lastProgress = 0

        while offset < fileSize {
            let chunkSize = min(uploadChunkSize, Int(fileSize - offset))
            let chunk = try AudioFileManager.readChunk(
                path: filePath, offset: offset, size: chunkSize)

            try await ws.sendBinary(chunk)
            offset += Int64(chunkSize)

            let progress = Int((Double(offset) / Double(fileSize)) * 100)
            if progress != lastProgress && progress % 10 == 0 {
                Logger.info("Upload progress: \(progress)% (\(offset) / \(fileSize) bytes)")
                lastProgress = progress
            }
        }

        Logger.info("Upload progress: 100% (\(fileSize) / \(fileSize) bytes)")

        // Send STOP message (no response expected, matching Java implementation)
        try await ws.sendText(WebSocketMessage.stop(streamId: streamId))
        Logger.info("Sent STOP message")

        Logger.info("Upload completed")

        return streamId
    }
}
