package server

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }

/** WebSocket JSON message DTO. */
@Serializable
data class Message(
    @SerialName("command") val command: String,
    @SerialName("streamId") val streamId: String? = null,
    @SerialName("offset") val offset: Long? = null,
    @SerialName("length") val length: Int? = null,
    @SerialName("message") val message: String? = null,
    @SerialName("status") val status: String? = null,
    @SerialName("size") val size: Long? = null,
    @SerialName("streams") val streams: String? = null,
) {
    fun toJson(): String = json.encodeToString(serializer(), this)

    companion object {
        fun connected(connId: String)  = Message(command = "CONNECTED", streamId = connId)
        fun created(streamId: String)  = Message(command = "CREATED", streamId = streamId)
        fun completed(streamId: String)= Message(command = "COMPLETED", streamId = streamId)
        fun closed(streamId: String)   = Message(command = "CLOSED", streamId = streamId)
        fun error(msg: String)         = Message(command = "ERROR", message = msg)

        fun status(streamId: String, status: String, size: Long) =
            Message(command = "STATUS", streamId = streamId, status = status, size = size)

        fun streamList(ids: List<String>) =
            Message(command = "STREAM_LIST", streams = ids.joinToString(","))

        fun parse(text: String): Pair<Message, CommandInfo> {
            val m = json.decodeFromString(serializer(), text)
            val info = CommandInfo.lookup(m.command)
            return m to info
        }
    }
}
