package client.core

import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.websocket.*
import io.ktor.websocket.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import WebSocketMessage
import Logger
import kotlin.time.Duration.Companion.seconds

/**
 * WebSocket client for audio streaming
 */
class WebSocketClient(private val uri: String) {
    private val client = HttpClient(CIO) {
        install(WebSockets) {
            pingInterval = 20.seconds
            maxFrameSize = Long.MAX_VALUE
        }
    }
    
    private lateinit var session: DefaultClientWebSocketSession
    
    suspend fun <T> withConnection(block: suspend () -> T): T {
        Logger.info("Connecting to $uri")
        
        return try {
            var result: T? = null
            client.webSocket(uri) {
                session = this
                Logger.info("Connected to server")
                
                // Read and ignore the initial "connected" message from server
                try {
                    val initialFrame = incoming.receive()
                    if (initialFrame is Frame.Text) {
                        val text = initialFrame.readText()
                        Logger.debug("Received initial message: $text")
                    }
                } catch (e: Exception) {
                    Logger.debug("No initial message from server")
                }
                
                result = block()
            }
            result!!
        } catch (e: Exception) {
            Logger.error("WebSocket error: ${e.message}")
            throw e
        } finally {
            client.close()
            Logger.info("Disconnected from server")
        }
    }
    
    suspend fun sendText(message: WebSocketMessage) {
        val json = Json.encodeToString(message)
        Logger.debug("Sending: $json")
        session.send(Frame.Text(json))
    }
    
    suspend fun sendBinary(data: ByteArray) {
        Logger.debug("Sending binary data: ${data.size} bytes")
        session.send(Frame.Binary(true, data))
    }
    
    suspend fun receiveText(): String {
        val frame = session.incoming.receive()
        return when (frame) {
            is Frame.Text -> {
                val text = frame.readText()
                Logger.debug("Received: $text")
                text
            }
            else -> throw Exception("Expected text message, got: ${frame::class.simpleName}")
        }
    }

    suspend fun receiveBinary(): ByteArray {
        val frame = session.incoming.receive()
        return when (frame) {
            is Frame.Binary -> {
                val data = frame.readBytes()
                Logger.debug("Received binary data: ${data.size} bytes")
                data
            }
            is Frame.Text -> {
                val text = frame.readText()
                Logger.debug("Received text message instead of binary: $text")
                // Try to parse as error response
                try {
                    val jsonParser = Json { ignoreUnknownKeys = true }
                    val msg = jsonParser.decodeFromString<WebSocketMessage>(text)
                    if (msg.type == "ERROR") {
                        throw Exception("Server error: ${msg.message}")
                    }
                } catch (e: Exception) {
                    // Ignore parse errors, fall through to default error
                }
                throw Exception("Expected binary message, got text: $text")
            }
            else -> throw Exception("Expected binary message, got: ${frame::class.simpleName}")
        }
    }
}
