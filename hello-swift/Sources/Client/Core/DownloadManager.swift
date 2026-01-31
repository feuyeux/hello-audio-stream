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
        let maxRetries = 3

        while offset < fileSize {
            let length = min(downloadChunkSize, Int(fileSize - offset))

            // Send GET message
            try await ws.sendText(
                WebSocketMessage(
                    type: MessageType.GET.rawValue,
                    streamId: streamId,
                    offset: offset,
                    length: length,
                    message: nil
                ))

            // Receive binary data with timeout
            var receivedData: Data?
            var retries = 0

            while retries < maxRetries {
                do {
                    // Try to receive data with a timeout
                    receivedData = try await withThrowingTaskGroup(of: Data?.self) { group in
                        // Task 1: Wait for binary data
                        group.addTask {
                            return try? await ws.receiveBinary()
                        }

                        // Task 2: Timeout
                        group.addTask {
                            try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
                            return nil  // Timeout
                        }

                        // Wait for first result
                        let result = try await group.next()!
                        group.cancelAll()
                        return result
                    }

                    if receivedData != nil {
                        break
                    } else {
                        // Timeout occurred
                        Logger.warn("No data received at offset \(offset), retry \(retries + 1)/\(maxRetries)")
                        retries += 1
                        if retries < maxRetries {
                            // Send GET request again
                            try await ws.sendText(
                                WebSocketMessage(
                                    type: MessageType.GET.rawValue,
                                    streamId: streamId,
                                    offset: offset,
                                    length: length,
                                    message: nil
                                ))
                        }
                    }
                } catch {
                    Logger.error("Error receiving data: \(error)")
                    retries += 1
                }
            }

            // If we still don't have data after all retries, throw error
            guard let data = receivedData else {
                throw NSError(
                    domain: "Download", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to receive data at offset \(offset) after \(maxRetries) retries"
                    ])
            }

            // Write to file
            try AudioFileManager.writeChunk(path: outputPath, data: data, append: true)
            offset += Int64(data.count)

            // Check if we received less data than requested - indicates end of file
            if data.count < length {
                Logger.info("Received partial chunk (\(data.count) < \(length) bytes), download complete")
                break
            }

            // Report progress
            let progress = Int((Double(offset) / Double(fileSize)) * 100)
            if progress >= lastProgress + 25 && progress > lastProgress {
                Logger.info("Download progress: \(progress)% (\(offset) / \(fileSize) bytes)")
                lastProgress = (progress / 25) * 25
            }
        }

        Logger.info("Download progress: 100% (\(offset) / \(fileSize) bytes)")
        Logger.info("Download completed")
    }
}
