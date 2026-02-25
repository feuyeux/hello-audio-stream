import client.Client
import kotlinx.coroutines.runBlocking
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Unified entry point — dispatches to server or client mode.
 * Usage: java -jar app.jar server [--port 8080]
 *        java -jar app.jar [client] --input FILE [--server URI] [--output FILE]
 */
fun main(args: Array<String>) {
    val mode = if (args.isNotEmpty()) args[0].lowercase() else "client"

    if (mode == "server") {
        server.main(args.drop(1).toTypedArray())
    } else {
        val rest = if (mode == "client") args.drop(1).toTypedArray() else args
        runClient(rest)
    }
}

private fun runClient(args: Array<String>) = runBlocking {
    var input: String? = null
    var output: String? = null
    var serverUri = "ws://localhost:8080"
    var streamId: String? = null

    var i = 0
    while (i < args.size) {
        when (args[i]) {
            "--input", "-i" -> if (i + 1 < args.size) input = args[++i]
            "--output", "-o" -> if (i + 1 < args.size) output = args[++i]
            "--server", "-s" -> if (i + 1 < args.size) serverUri = args[++i]
            "--stream-id" -> if (i + 1 < args.size) streamId = args[++i]
        }
        i++
    }

    requireNotNull(input) { "--input FILE is required" }
    require(File(input).exists()) { "Input file not found: $input" }

    if (output == null) {
        val ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"))
        output = "audio/output/output-$ts-${File(input).name}"
    }
    if (streamId == null) {
        streamId = "stream-${System.currentTimeMillis()}"
    }

    println("Input: $input (${File(input).length()} bytes)")
    Client(serverUri).run(input, output, streamId)
}
