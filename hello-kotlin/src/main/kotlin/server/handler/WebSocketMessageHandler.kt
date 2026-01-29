// WebSocket message handler for processing client messages.
// Handles START, STOP, and GET message types.
// Matches Java WebSocketMessageHandler functionality.

package server.handler

import MessageType
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import server.Logger
import server.memory.StreamManager
import java.util.concurrent.ConcurrentHashMap

/**
 * WebSocket message types - serializable data class
 */
@Serializable
data class WebSocketMessage(
    val type: String,
    val streamId: String? = null,
    val offset: Long? = null,
    val length: Int? = null,
    val message: String? = null
) {
    companion object {
        private val jsonParser = Json { 
            ignoreUnknownKeys = true 
            encodeDefaults = false
        }

        fun fromJsonString(jsonString: String): WebSocketMessage {
            return jsonParser.decodeFromString<WebSocketMessage>(jsonString)
        }

        fun started(streamId: String, message: String = "Stream created"): WebSocketMessage {
            return WebSocketMessage(type = "STARTED", streamId = streamId, message = message)
        }

        fun stopped(streamId: String, message: String = "Stream finalized"): WebSocketMessage {
            return WebSocketMessage(type = "stopped", streamId = streamId, message = message)
        }

        fun error(message: String): WebSocketMessage {
            return WebSocketMessage(type = "ERROR", message = message)
        }

        /**
         * Parse string to MessageType enum
         */
        fun getMessageTypeEnum(type: String?): MessageType? {
            return MessageType.fromString(type)
        }
    }

    fun toJson(): String {
        return jsonParser.encodeToString(this)
    }
}

/**
 * WebSocket message handler for processing client messages.
 */
class WebSocketMessageHandler(
    private val streamManager: StreamManager
) {
    private val activeStreams: ConcurrentHashMap<Long, String> = ConcurrentHashMap() // Maps client ID to stream ID - thread-safe

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
            val data = WebSocketMessage.fromJsonString(message)
            val messageType = WebSocketMessage.getMessageTypeEnum(data.type)

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

            val response = WebSocketMessage.started(data.streamId)

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
            val response = WebSocketMessage.stopped(data.streamId)

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
