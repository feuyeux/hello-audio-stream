package client

import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.websocket.*
import io.ktor.websocket.*
import server.Message
import server.json
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import kotlin.time.Duration.Companion.seconds

private const val CHUNK_SIZE = 64 * 1024 // 64 KB

/** Audio stream client — connects, uploads, downloads, verifies. */
class Client(private val uri: String) {
    private val httpClient = HttpClient(CIO) {
        install(WebSockets) {
            pingInterval = 20.seconds
            maxFrameSize = Long.MAX_VALUE
        }
    }

    private lateinit var session: DefaultClientWebSocketSession
    private var connId: String? = null

    /** Run the full workflow: connect → upload → download → verify → close. */
    suspend fun run(inputFile: String, outputFile: String, streamId: String) {
        httpClient.webSocket(uri) {
            session = this

            // CONNECTED
            val connFrame = incoming.receive() as Frame.Text
            val connMsg = json.decodeFromString(Message.serializer(), connFrame.readText())
            require(connMsg.command == "CONNECTED") { "Expected CONNECTED, got ${connMsg.command}" }
            connId = connMsg.streamId
            println("Connected as $connId")

            upload(inputFile, streamId)
            kotlinx.coroutines.delay(1000)
            download(streamId, outputFile, File(inputFile).length())
        }
        httpClient.close()

        if (verify(inputFile, outputFile)) {
            println("Workflow complete — files match")
        } else {
            throw RuntimeException("Verification failed")
        }
    }

    private suspend fun DefaultClientWebSocketSession.upload(filePath: String, streamId: String) {
        // CREATE
        send(Frame.Text(Message(command = "CREATE", streamId = streamId).toJson()))
        val resp = receiveJson()
        require(resp.command == "CREATED") { "Expected CREATED, got ${resp.command}" }
        println("Stream created: $streamId")

        // Send binary data
        val fileSize = File(filePath).length()
        var sent = 0L
        val t0 = System.nanoTime()
        FileInputStream(filePath).use { fis ->
            val buf = ByteArray(CHUNK_SIZE)
            while (true) {
                val n = fis.read(buf)
                if (n <= 0) break
                send(Frame.Binary(true, buf.copyOf(n)))
                sent += n
            }
        }
        val elapsed = (System.nanoTime() - t0) / 1_000_000.0
        val mbps = fileSize * 8.0 / 1_000_000 / (elapsed / 1000)
        println("Uploaded $sent bytes in ${"%.1f".format(elapsed)} ms (${"%.1f".format(mbps)} Mbps)")

        // COMPLETE
        send(Frame.Text(Message(command = "COMPLETE").toJson()))
        val compResp = receiveJson()
        require(compResp.command == "COMPLETED") { "Expected COMPLETED, got ${compResp.command}" }
        println("Stream completed: $streamId")
    }

    private suspend fun DefaultClientWebSocketSession.download(streamId: String, outputPath: String, expectedSize: Long) {
        File(outputPath).parentFile?.mkdirs()
        var received = 0L
        val t0 = System.nanoTime()
        FileOutputStream(outputPath).use { fos ->
            while (received < expectedSize) {
                val length = minOf(CHUNK_SIZE.toLong(), expectedSize - received).toInt()
                send(Frame.Text(Message(command = "READ", streamId = streamId, offset = received, length = length).toJson()))
                val frame = incoming.receive()
                when (frame) {
                    is Frame.Binary -> {
                        val data = frame.readBytes()
                        fos.write(data)
                        received += data.size
                    }
                    is Frame.Text -> {
                        val msg = json.decodeFromString(Message.serializer(), frame.readText())
                        if (msg.command == "ERROR") throw RuntimeException("Server error: ${msg.message}")
                        throw RuntimeException("Expected binary, got text: ${msg.command}")
                    }
                    else -> throw RuntimeException("Unexpected frame type")
                }
            }
        }
        val elapsed = (System.nanoTime() - t0) / 1_000_000.0
        val mbps = received * 8.0 / 1_000_000 / (elapsed / 1000)
        println("Downloaded $received bytes in ${"%.1f".format(elapsed)} ms (${"%.1f".format(mbps)} Mbps)")
    }

    private suspend fun DefaultClientWebSocketSession.receiveJson(): Message {
        val frame = incoming.receive() as Frame.Text
        return json.decodeFromString(Message.serializer(), frame.readText())
    }

    companion object {
        fun verify(original: String, downloaded: String): Boolean {
            val origSize = File(original).length()
            val dlSize = File(downloaded).length()
            if (origSize != dlSize) {
                System.err.println("Size mismatch: $origSize vs $dlSize")
                return false
            }
            val h1 = md5(original)
            val h2 = md5(downloaded)
            if (h1 != h2) {
                System.err.println("Checksum mismatch: $h1 vs $h2")
                return false
            }
            println("Verification passed (MD5: $h1)")
            return true
        }

        private fun md5(path: String): String {
            val digest = MessageDigest.getInstance("MD5")
            FileInputStream(path).use { fis ->
                val buf = ByteArray(CHUNK_SIZE)
                var n: Int
                while (fis.read(buf).also { n = it } > 0) {
                    digest.update(buf, 0, n)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
    }
}
