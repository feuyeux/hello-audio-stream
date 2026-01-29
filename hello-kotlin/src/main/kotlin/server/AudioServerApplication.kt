// Main entry point for Kotlin audio stream server.

package server

import server.memory.StreamManager
import server.memory.MemoryPoolManager
import server.network.AudioWebSocketServer

/**
 * Main entry point for audio server application
 */
object AudioServerApplication {
    @JvmStatic
    fun main(args: Array<String>) {
        // Parse command-line arguments
        var port = 8080
        var path = "/audio"
        
        var i = 0
        while (i < args.size) {
            when (args[i]) {
                "--port" -> {
                    if (i + 1 < args.size) {
                        port = args[i + 1].toIntOrNull() ?: 8080
                        i++
                    }
                }
                "--path" -> {
                    if (i + 1 < args.size) {
                        path = args[i + 1]
                        i++
                    }
                }
            }
            i++
        }
        
        Logger.info("Starting Audio Server on port $port with path $path")

        // Get singleton instances
        val streamManager = StreamManager.getInstance("cache")
        val memoryPool = MemoryPoolManager.getInstance()

        // Create and start WebSocket server
        val server = AudioWebSocketServer(
            port = port,
            path = path,
            streamManager = streamManager,
            memoryPool = memoryPool
        )

        // Handle graceful shutdown
        Runtime.getRuntime().addShutdownHook(Thread {
            Logger.info("Shutting down server...")
            server.stop()
        })

        Logger.info("Starting server... Press Ctrl+C to stop.")

        // Start server
        server.start()
    }
}
