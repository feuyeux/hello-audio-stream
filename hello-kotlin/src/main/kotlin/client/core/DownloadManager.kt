package client.core

import WebSocketMessage
import Logger

/**
 * Download manager
 */
object DownloadManager {
    suspend fun download(ws: WebSocketClient, streamId: String, outputPath: String, fileSize: Long) {
        Logger.info("========================================")
        Logger.info("Phase 2: Download")
        Logger.info("========================================")
        Logger.info("Output path: $outputPath")
        Logger.info("Expected size: $fileSize bytes")

        // Delete output file if it exists
        FileManager.deleteFile(outputPath)

        var offset = 0L
        var lastProgress = 0

        while (offset < fileSize) {
            val length = minOf(ChunkManager.DOWNLOAD_CHUNK_SIZE.toLong(), fileSize - offset).toInt()

            // Send GET message
            ws.sendText(WebSocketMessage(
                type = "GET",
                streamId = streamId,
                offset = offset,
                length = length
            ))
            
            // Receive binary data
            val data = ws.receiveBinary()
            if (data == null) {
                throw Exception("Failed to receive data at offset $offset")
            }
            
            // Write to file
            FileManager.writeChunk(outputPath, data, append = true)
            offset += data.size
            
            // Report progress
            val progress = ((offset.toDouble() / fileSize) * 100).toInt()
            if (progress >= lastProgress + 25 && progress > lastProgress) {
                Logger.info("Download progress: $progress% ($offset / $fileSize bytes)")
                lastProgress = (progress / 25) * 25
            }
        }
        
        Logger.info("Download progress: 100% ($fileSize / $fileSize bytes)")
        Logger.info("Download completed")
    }
}
