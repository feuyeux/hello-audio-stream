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

        // Send START message
        try await ws.sendText(
            WebSocketMessage(
                type: "start", streamId: streamId, offset: nil, length: nil, message: nil))

        // Wait for START_ACK
        guard let startAck = try await ws.receiveText(), startAck.contains("\"type\":\"STARTED\"")
        else {
            throw NSError(
                domain: "Upload", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to receive START_ACK"])
        }
        Logger.debug("Received START_ACK")

        // Upload file in chunks
        var offset: Int64 = 0
        var lastProgress = 0

        while offset < fileSize {
            let chunkSize = min(uploadChunkSize, Int(fileSize - offset))
            let chunk = try AudioFileManager.readChunk(
                path: filePath, offset: offset, size: chunkSize)

            try await ws.sendBinary(chunk)
            offset += Int64(chunk.count)

            // Report progress
            let progress = Int((Double(offset) / Double(fileSize)) * 100)
            if progress >= lastProgress + 25 && progress > lastProgress {
                Logger.info("Upload progress: \(progress)% (\(offset) / \(fileSize) bytes)")
                lastProgress = (progress / 25) * 25
            }
        }

        Logger.info("Upload progress: 100% (\(fileSize) / \(fileSize) bytes)")

        // Send STOP message
        try await ws.sendText(
            WebSocketMessage(
                type: "stop", streamId: streamId, offset: nil, length: nil, message: nil))

        // Wait for STOP_ACK
        guard let stopAck = try await ws.receiveText(), stopAck.contains("\"type\":\"STOPPED\"")
        else {
            throw NSError(
                domain: "Upload", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to receive STOP_ACK"])
        }
        Logger.debug("Received STOP_ACK")

        Logger.info("Upload completed")

        return streamId
    }
}
