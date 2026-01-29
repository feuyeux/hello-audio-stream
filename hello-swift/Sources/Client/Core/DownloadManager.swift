import AudioStreamCommon
import Foundation

/// Download manager
class DownloadManager {
    private static let downloadChunkSize = 8192  // 8KB per GET request

    static func download(ws: WebSocketClient, streamId: String, outputPath: String, fileSize: Int64)
        async throws
    {
        Logger.info("========================================")
        Logger.info("Phase 2: Download")
        Logger.info("========================================")
        Logger.info("Output path: \(outputPath)")
        Logger.info("Expected size: \(fileSize) bytes")

        // Delete output file if it exists
        AudioFileManager.deleteFile(path: outputPath)

        var offset: Int64 = 0
        var lastProgress = 0

        while offset < fileSize {
            let length = min(downloadChunkSize, Int(fileSize - offset))

            // Send GET message
            try await ws.sendText(
                WebSocketMessage(
                    type: "GET",
                    streamId: streamId,
                    offset: offset,
                    length: length,
                    message: nil
                ))

            // Receive binary data
            guard let data = try await ws.receiveBinary() else {
                throw NSError(
                    domain: "Download", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to receive data at offset \(offset)"
                    ])
            }

            // Write to file
            try AudioFileManager.writeChunk(path: outputPath, data: data, append: true)
            offset += Int64(data.count)

            // Report progress
            let progress = Int((Double(offset) / Double(fileSize)) * 100)
            if progress >= lastProgress + 25 && progress > lastProgress {
                Logger.info("Download progress: \(progress)% (\(offset) / \(fileSize) bytes)")
                lastProgress = (progress / 25) * 25
            }
        }

        Logger.info("Download progress: 100% (\(fileSize) / \(fileSize) bytes)")
        Logger.info("Download completed")
    }
}
