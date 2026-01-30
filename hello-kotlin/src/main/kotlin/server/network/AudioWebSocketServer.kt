// WebSocket server for audio streaming.
// Handles client connections and message routing.
// Matches Python WebSocketServer and Java AudioWebSocketServer functionality.

package server.network

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.cio.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.channels.ClosedReceiveChannelException
import server.Logger
import server.handler.WebSocketMessageHandler
import server.handler.WebSocketMessage
import server.memory.StreamManager
import server.memory.MemoryPoolManager
import kotlin.time.Duration.Companion.seconds
import java.util.concurrent.ConcurrentHashMap

/**
 * WebSocket server for handling audio stream uploads and downloads.
 */
class AudioWebSocketServer(
    private val port: Int = 8080,
    private val path: String = "/audio",
    streamManager: StreamManager? = null,
    memoryPool: MemoryPoolManager? = null
) {
    private val streamManager: StreamManager = streamManager ?: StreamManager.getInstance()
    private val memoryPool: MemoryPoolManager = memoryPool ?: MemoryPoolManager.getInstance()
    private val messageHandler: WebSocketMessageHandler = WebSocketMessageHandler(this.streamManager)
    private val clients = ConcurrentHashMap<DefaultWebSocketSession, Long>()
    private var server: EmbeddedServer<CIOApplicationEngine, CIOApplicationEngine.Configuration>? = null

    init {
        Logger.info("AudioWebSocketServer initialized on port $port$path")
    }

    /**
     * Start the WebSocket server.
     */
    fun start() {
        server = embeddedServer(CIO, port = port) {
            install(WebSockets) {
                pingPeriod = 15.seconds
                timeout = 15.seconds
                maxFrameSize = Long.MAX_VALUE
                masking = false
            }

            routing {
                webSocket(path) {
                    val clientId = System.nanoTime()
                    clients[this] = clientId
                    
                    Logger.info("Client connected: $clientId")
                    
                    // Send connection established message
                    send(Frame.Text("{\"type\":\"connected\",\"message\":\"Connection established\"}"))

                    try {
                        for (frame in incoming) {
                            when (frame) {
                                is Frame.Text -> {
                                    val text = frame.readText()
                                    handleTextMessage(this, clientId, text)
                                }
                                is Frame.Binary -> {
                                    val data = frame.readBytes()
                                    handleBinaryMessage(this, clientId, data)
                                }
                                is Frame.Close -> {
                                    Logger.info("Client disconnected: $clientId")
                                    break
                                }
                                else -> {}
                            }
                        }
                    } catch (e: ClosedReceiveChannelException) {
                        Logger.info("Client connection closed: $clientId")
                    } catch (e: Exception) {
                        Logger.error("Error handling client $clientId: ${e.message}")
                    } finally {
                        clients.remove(this)
                    }
                }
            }
        }

        Logger.info("WebSocket server started on ws://0.0.0.0:$port$path")
        server?.start(wait = true)
    }

    /**
     * Stop the WebSocket server.
     */
    fun stop() {
        server?.stop(1000, 2000)
        Logger.info("WebSocket server stopped")
    }

    /**
     * Handle a text (JSON) control message.
     */
    private suspend fun handleTextMessage(session: DefaultWebSocketSession, clientId: Long, message: String) {
        Logger.debug("Received text message: $message")
        
        // Check message type
        val messageType = parseSimpleJson(message)["type"] as? String
        
        when (messageType?.lowercase()) {
            "GET" -> {
                // Handle GET request - read and send binary data
                val streamId = parseSimpleJson(message)["streamId"] as? String
                val offset = (parseSimpleJson(message)["offset"] as? Number)?.toLong() ?: 0
                val length = (parseSimpleJson(message)["length"] as? Number)?.toInt() ?: 65536
                
                if (streamId != null) {
                    val data = streamManager.readChunk(streamId, offset, length)
                    if (data.isNotEmpty()) {
                        sendBinary(session, data)
                        Logger.info("Sent ${data.size} bytes for stream $streamId at offset $offset")
                    } else {
                        sendError(session, "No data available at offset $offset")
                    }
                } else {
                    sendError(session, "Missing streamId in get request")
                }
            }
            else -> {
                // Handle other messages through message handler
                messageHandler.handleTextMessage(
                    clientId,
                    message,
                    { data -> sendJson(session, data) },
                    { msg -> sendError(session, msg) }
                )
            }
        }
    }
    
    /**
     * Simple JSON parser for extracting fields
     */
    private fun parseSimpleJson(json: String): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        
        val typeRegex = """"type"\s*:\s*"([^"]+)"""".toRegex()
        typeRegex.find(json)?.let { match ->
            result["type"] = match.groupValues[1]
        }
        
        val streamIdRegex = """"streamId"\s*:\s*"([^"]+)"""".toRegex()
        streamIdRegex.find(json)?.let { match ->
            result["streamId"] = match.groupValues[1]
        }
        
        val offsetRegex = """"offset"\s*:\s*(\d+)""".toRegex()
        offsetRegex.find(json)?.let { match ->
            result["offset"] = match.groupValues[1].toLong()
        }
        
        val lengthRegex = """"length"\s*:\s*(\d+)""".toRegex()
        lengthRegex.find(json)?.let { match ->
            result["length"] = match.groupValues[1].toInt()
        }
        
        return result
    }

    /**
     * Handle binary audio data.
     */
    private fun handleBinaryMessage(session: DefaultWebSocketSession, clientId: Long, data: ByteArray) {
        messageHandler.handleBinaryMessage(clientId, data)
    }

    /**
     * Send a JSON message to the client.
     */
    private suspend fun sendJson(session: DefaultWebSocketSession, data: WebSocketMessage) {
        try {
            val json = toJson(data)
            session.send(Frame.Text(json))
            Logger.debug("Sent JSON to client: $json")
        } catch (e: Exception) {
            Logger.error("Error sending JSON message: ${e.message}")
        }
    }

    /**
     * Send an error message to the client.
     */
    private suspend fun sendError(session: DefaultWebSocketSession, message: String) {
        val response = WebSocketMessage(
            type = "ERROR",
            message = message
        )
        sendJson(session, response)
        Logger.error("Sent error to client: $message")
    }

    /**
     * Send binary data to the client.
     */
    suspend fun sendBinary(session: DefaultWebSocketSession, data: ByteArray) {
        try {
            session.send(Frame.Binary(true, data))
        } catch (e: Exception) {
            Logger.error("Error sending binary data: ${e.message}")
        }
    }

    /**
     * Simple JSON serializer (placeholder).
     * In production, use a proper JSON library.
     */
    private fun toJson(message: WebSocketMessage): String {
        val sb = StringBuilder()
        sb.append("{\"type\":\"${message.type}\"")

        if (message.streamId != null) {
            sb.append(",\"streamId\":\"${message.streamId}\"")
        }
        if (message.offset != null) {
            sb.append(",\"offset\":${message.offset}")
        }
        if (message.length != null) {
            sb.append(",\"length\":${message.length}")
        }
        if (message.message != null) {
            sb.append(",\"message\":\"${message.message}\"")
        }
        sb.append("}")

        return sb.toString()
    }
}
