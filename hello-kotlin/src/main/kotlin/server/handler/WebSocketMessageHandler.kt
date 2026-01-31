// WebSocket message handler for processing client messages.
// Handles START, STOP, and GET message types.
// Matches Java WebSocketMessageHandler functionality.

package server.handler

import MessageType
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import server.Logger
import server.memory.StreamManager
import WebSocketMessage
import java.util.concurrent.ConcurrentHashMap

/**
 * WebSocket message handler for processing client messages.
 */
class WebSocketMessageHandler(
    private val streamManager: StreamManager
) {
    private val activeStreams: ConcurrentHashMap<Long, String> = ConcurrentHashMap() // Maps client ID to stream ID - thread-safe
    private val jsonParser = Json { ignoreUnknownKeys = true }

    /**
     * Handle a text (JSON) control message.
     */
    suspend fun handleTextMessage(
        clientId: Long,
        message: String,
        sendJson: suspend (WebSocketMessage) -> Unit,
        sendError: suspend (String) -> Unit
    ) {
        return try {
            val data = jsonParser.decodeFromString<WebSocketMessage>(message)
            val messageType = MessageType.fromString(data.type)

            when (messageType) {
                MessageType.START -> handleStart(clientId, data, sendJson, sendError)
                MessageType.STOP -> handleStop(clientId, data, sendJson, sendError)
                MessageType.GET -> handleGet(clientId, data, sendJson, sendError)
                else -> {
                    Logger.warning("Unknown message type: ${data.type}")
                    sendError("Unknown message type: ${data.type}")
                }
            }
        } catch (e: Exception) {
            Logger.error("Error parsing JSON message: ${e.message}")
            sendError("Invalid JSON format")
        }
    }

    /**
     * Handle binary audio data.
     */
    fun handleBinaryMessage(clientId: Long, data: ByteArray) {
        // Get active stream ID for this client
        val streamId = activeStreams[clientId]
        if (streamId.isNullOrEmpty()) {
            Logger.warning("Received binary data but no active stream for client $clientId")
            return
        }

        Logger.debug("Received ${data.size} bytes of binary data for stream $streamId")

        // Write to stream
        streamManager.writeChunk(streamId, data)
    }

    /**
     * Handle START message (create new stream).
     */
    private suspend fun handleStart(
        clientId: Long,
        data: WebSocketMessage,
        sendJson: suspend (WebSocketMessage) -> Unit,
        sendError: suspend (String) -> Unit
    ) {
        if (data.streamId.isNullOrEmpty()) {
            sendError("Missing streamId")
            return
        }

        // Create stream
        if (streamManager.createStream(data.streamId)) {
            // Register this client with the stream
            activeStreams[clientId] = data.streamId

            val response = WebSocketMessage(
                type = MessageType.STARTED.value,
                streamId = data.streamId,
                message = "Stream created"
            )

            sendJson(response)
            Logger.info("Stream started: ${data.streamId}")
        } else {
            sendError("Failed to create stream: ${data.streamId}")
        }
    }

    /**
     * Handle STOP message (finalize stream).
     */
    private suspend fun handleStop(
        clientId: Long,
        data: WebSocketMessage,
        sendJson: suspend (WebSocketMessage) -> Unit,
        sendError: suspend (String) -> Unit
    ) {
        if (data.streamId.isNullOrEmpty()) {
            sendError("Missing streamId")
            return
        }

        // Finalize stream
        if (streamManager.finalizeStream(data.streamId)) {
            val response = WebSocketMessage(
                type = MessageType.STOPPED.value,
                streamId = data.streamId,
                message = "Stream finalized"
            )

            sendJson(response)
            Logger.info("Stream finalized: ${data.streamId}")

            // Unregister stream from client
            activeStreams[clientId] = ""
        } else {
            sendError("Failed to finalize stream: ${data.streamId}")
        }
    }

    /**
     * Handle GET message (read stream data).
     */
    private suspend fun handleGet(
        clientId: Long,
        data: WebSocketMessage,
        sendJson: suspend (WebSocketMessage) -> Unit,
        sendError: suspend (String) -> Unit
    ) {
        if (data.streamId.isNullOrEmpty()) {
            sendError("Missing streamId")
            return
        }

        val offset = data.offset ?: 0
        val length = data.length ?: 65536

        // Read data from stream
        val chunkData = streamManager.readChunk(data.streamId, offset, length)

        if (chunkData.isNotEmpty()) {
            // Send binary data (handled by caller)
            Logger.debug("Prepared ${chunkData.size} bytes for stream ${data.streamId} at offset $offset")
            // Note: The actual binary sending needs to be handled by the server
        } else {
            sendError("Failed to read from stream: ${data.streamId}")
        }
    }
}
