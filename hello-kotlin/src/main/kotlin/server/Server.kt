package server

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.cio.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicInteger
import kotlin.time.Duration.Companion.seconds

/** WebSocket audio stream server using Ktor CIO. */
class Server(
    private val port: Int = 8080,
    private val cacheDir: String = "audio/output",
) {
    private val mgr = StreamManager(cacheDir)
    private val connSeq = AtomicInteger(0)

    fun start() {
        val server = embeddedServer(CIO, port = port) {
            install(WebSockets) {
                pingPeriod = 20.seconds
                timeout = 20.seconds
                maxFrameSize = Long.MAX_VALUE
            }
            routing {
                webSocket("/") { handleConnection(this) }
                // Also accept without trailing slash
                webSocket { handleConnection(this) }
            }
        }

        // Cleanup timer
        val cleanupJob = CoroutineScope(Dispatchers.Default).launch {
            while (isActive) {
                delay(30_000)
                try {
                    val removed = mgr.cleanup()
                    if (removed > 0) println("Cleanup removed $removed stream(s)")
                    val s = mgr.stats()
                    println("Stats: total=${s.total} uploading=${s.uploading} ready=${s.ready} error=${s.error}")
                } catch (e: Exception) {
                    System.err.println("Cleanup error: ${e.message}")
                }
            }
        }

        println("Server listening on ws://0.0.0.0:$port")
        Runtime.getRuntime().addShutdownHook(Thread {
            println("Shutting down...")
            cleanupJob.cancel()
            server.stop(1000, 2000)
        })
        server.start(wait = true)
    }

    private suspend fun handleConnection(session: DefaultWebSocketServerSession) {
        val connId = "c-${connSeq.incrementAndGet()}"
        println("[$connId] connected")
        val handler = Handler(mgr, connId, session)
        handler.run()
    }
}

/** Entry point: `java -cp <jar> server.MainKt --port 8080` */
fun main(args: Array<String>) {
    var port = 8080
    var cacheDir = "audio/output"
    var i = 0
    while (i < args.size) {
        when (args[i]) {
            "--port" -> if (i + 1 < args.size) port = args[++i].toIntOrNull() ?: 8080
            "--cache-dir" -> if (i + 1 < args.size) cacheDir = args[++i]
        }
        i++
    }
    Server(port, cacheDir).start()
}
