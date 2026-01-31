package client

import client.core.WebSocketClient
import client.core.UploadManager
import client.core.DownloadManager
import client.core.FileManager
import client.util.PerformanceMonitor
import client.util.VerificationModule
import CliParser
import Logger
import kotlinx.coroutines.runBlocking
import kotlin.system.exitProcess

/**
 * Main entry point for audio client application
 */
object AudioClientApplication {
    @JvmStatic
    fun main(args: Array<String>): Unit = runBlocking {
        try {
            // Parse CLI arguments
            val config = CliParser.parse(args) ?: exitProcess(1)
            
            Logger.info("Audio Stream Client")
            Logger.info("Input: ${config.inputPath}")
            Logger.info("Output: ${config.outputPath}")
            Logger.info("Server: ${config.serverUri}")
            
            // Initialize performance monitor
            val performance = PerformanceMonitor()
            val fileSize = FileManager.getFileSize(config.inputPath)
            performance.setFileSize(fileSize)
            
            // Connect to WebSocket server and perform operations
            val ws = WebSocketClient(config.serverUri)
            
            val verification = ws.withConnection {
                // Upload file
                performance.startUpload()
                val streamId = UploadManager.upload(ws, config.inputPath)
                performance.endUpload()
                
                // Sleep 2 seconds after upload
                Logger.info("Upload successful, sleeping for 2 seconds...")
                kotlinx.coroutines.delay(2000)
                
                // Download file
                performance.startDownload()
                DownloadManager.download(ws, streamId, config.outputPath, fileSize)
                performance.endDownload()
                
                // Sleep 2 seconds after download
                Logger.info("Download successful, sleeping for 2 seconds...")
                kotlinx.coroutines.delay(2000)
                
                // Verify integrity
                VerificationModule.verify(config.inputPath, config.outputPath)
            }
            
            // Report performance
            val report = performance.getReport()
            performance.printReport(report)
            
            // Exit with appropriate code
            if (verification.passed) {
                Logger.info("SUCCESS: Stream completed successfully")
                exitProcess(0)
            } else {
                Logger.error("FAILURE: File verification failed")
                exitProcess(1)
            }
        } catch (e: Exception) {
            Logger.error("Fatal error: ${e.message}")
            e.printStackTrace()
            exitProcess(1)
        }
    }
}
