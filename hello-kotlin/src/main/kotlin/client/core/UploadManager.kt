package client.core

import client.util.StreamIdGenerator
import WebSocketMessage
import Logger

/**
 * Upload manager
 */
object UploadManager {
    suspend fun upload(ws: WebSocketClient, filePath: String): String {
        val streamId = StreamIdGenerator.generate()
        val fileSize = FileManager.getFileSize(filePath)

        Logger.info("========================================")
        Logger.info("Phase 1: Upload")
        Logger.info("========================================")
        Logger.info("Stream ID: $streamId")
        Logger.info("File size: $fileSize bytes")

        // Send START message
        ws.sendText(WebSocketMessage(type = "START", streamId = streamId))

        // Wait for START_ACK (response type is "STARTED" or "started")
        val startAck = ws.receiveText()
        if (startAck == null || !(startAck.contains("\"type\":\"STARTED\"") || startAck.contains("\"type\":\"started\""))) {
            Logger.error("Unexpected response: $startAck")
            throw Exception("Failed to receive START_ACK")
        }
        Logger.debug("Received START_ACK")

        // Upload file in chunks
        var offset = 0L
        var lastProgress = 0

        while (offset < fileSize) {
            val chunkSize = minOf(ChunkManager.UPLOAD_CHUNK_SIZE.toLong(), fileSize - offset).toInt()
            val chunk = FileManager.readChunk(filePath, offset, chunkSize)

            ws.sendBinary(chunk)
            offset += chunk.size

            // Report progress
            val progress = ((offset.toDouble() / fileSize) * 100).toInt()
            if (progress >= lastProgress + 25 && progress > lastProgress) {
                Logger.info("Upload progress: $progress% ($offset / $fileSize bytes)")
                lastProgress = (progress / 25) * 25
            }
        }

        Logger.info("Upload progress: 100% ($fileSize / $fileSize bytes)")

        // Send STOP message
        ws.sendText(WebSocketMessage(type = "STOP", streamId = streamId))

        // Wait for STOP_ACK (response type is "STOPPED" or "stopped")
        val stopAck = ws.receiveText()
        if (stopAck == null || !(stopAck.contains("\"type\":\"STOPPED\"") || stopAck.contains("\"type\":\"stopped\""))) {
            Logger.error("Unexpected response: $stopAck")
            throw Exception("Failed to receive STOP_ACK")
        }
        Logger.debug("Received STOP_ACK")

        Logger.info("Upload completed")

        return streamId
    }
}
