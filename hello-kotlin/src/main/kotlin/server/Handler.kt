package server

import io.ktor.server.websocket.*
import io.ktor.websocket.*

/** Per-connection WebSocket handler. */
class Handler(
    private val mgr: StreamManager,
    private val connId: String,
    private val session: DefaultWebSocketServerSession,
) {
    private var streamId: String? = null

    /** Main message loop — call once per connection. */
    suspend fun run() {
        send(Message.connected(connId))
        try {
            for (frame in session.incoming) {
                when (frame) {
                    is Frame.Text -> handleText(frame.readText())
                    is Frame.Binary -> handleBinary(frame.readBytes())
                    else -> {}
                }
            }
        } finally {
            onClose()
        }
    }

    private fun onClose() {
        streamId?.let { try { mgr.markError(it) } catch (_: Exception) {} }
        println("[$connId] disconnected")
    }

    // ── dispatch ────────────────────────────────────────────────────────

    private suspend fun handleText(text: String) {
        try {
            val (m, info) = Message.parse(text)
            when (info.cmdType) {
                CommandType.STREAM -> handleStreamCmd(info.streamCmd!!, m)
                CommandType.DATA   -> handleDataCmd(m)
                CommandType.QUERY  -> handleQueryCmd(info.queryCmd!!, m)
            }
        } catch (e: Exception) {
            sendError(e.message ?: "Unknown error")
        }
    }

    private suspend fun handleBinary(data: ByteArray) {
        val sid = streamId
        if (sid == null) { sendError("No active upload stream"); return }
        try { mgr.write(sid, data) }
        catch (e: Exception) { sendError(e.message ?: "Write error") }
    }

    // ── stream commands ─────────────────────────────────────────────────

    private suspend fun handleStreamCmd(cmd: StreamCommand, m: Message) {
        try {
            when (cmd) {
                StreamCommand.CREATE -> {
                    val sid = m.streamId ?: throw IllegalArgumentException("CREATE requires streamId")
                    mgr.create(sid)
                    streamId = sid
                    send(Message.created(sid))
                }
                StreamCommand.COMPLETE -> {
                    val sid = streamId ?: throw IllegalStateException("No active stream")
                    mgr.complete(sid)
                    streamId = null
                    send(Message.completed(sid))
                }
                StreamCommand.CLOSE -> {
                    val sid = m.streamId ?: throw IllegalArgumentException("CLOSE requires streamId")
                    mgr.delete(sid)
                    send(Message.closed(sid))
                }
            }
        } catch (e: Exception) { sendError(e.message ?: "Stream command error") }
    }

    // ── data commands ───────────────────────────────────────────────────

    private suspend fun handleDataCmd(m: Message) {
        try {
            val sid = m.streamId ?: throw IllegalArgumentException("READ requires streamId")
            val offset = m.offset ?: 0
            val length = m.length ?: 65536
            val data = mgr.read(sid, offset, length)
            if (data.isNotEmpty()) session.send(Frame.Binary(true, data))
            else sendError("No data at requested offset")
        } catch (e: Exception) { sendError(e.message ?: "Read error") }
    }

    // ── query commands ──────────────────────────────────────────────────

    private suspend fun handleQueryCmd(cmd: QueryCommand, m: Message) {
        try {
            when (cmd) {
                QueryCommand.GET_STATUS -> {
                    val sid = m.streamId ?: throw IllegalArgumentException("GET_STATUS requires streamId")
                    val (st, size) = mgr.statusOf(sid)
                    send(Message.status(sid, st.name, size))
                }
                QueryCommand.LIST_STREAMS -> send(Message.streamList(mgr.list()))
            }
        } catch (e: Exception) { sendError(e.message ?: "Query error") }
    }

    // ── helpers ─────────────────────────────────────────────────────────

    private suspend fun send(m: Message) {
        try { session.send(Frame.Text(m.toJson())) } catch (_: Exception) {}
    }

    private suspend fun sendError(msg: String) {
        System.err.println("[$connId] error: $msg")
        send(Message.error(msg))
    }
}
