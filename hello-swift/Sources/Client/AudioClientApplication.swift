import Foundation
import ArgumentParser
import AudioStreamCommon

/// Thread-safe state for workflow execution
private final class WorkflowState: @unchecked Sendable {
    var hasError = false
    var finished = false
}

/// Command-line argument parser
struct AudioStreamClient: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audio_stream_client",
        abstract: "Audio Stream Client - Upload and download audio files via WebSocket"
    )
    
    @Option(name: .long, help: "Path to input audio file (required)")
    var input: String
    
    @Option(name: .long, help: "Path to output audio file (optional, default: audio/output/output-<timestamp>-<filename>)")
    var output: String?
    
    @Option(name: .long, help: "WebSocket server URI (optional, default: ws://localhost:8080/audio)")
    var server: String = "ws://localhost:8080/audio"
    
    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false
    
    func run() throws {
        // Set verbose mode
        Logger.setVerbose(verbose)
        
        // Validate input file
        guard FileManager.default.fileExists(atPath: input) else {
            Logger.error("Input file does not exist: \(input)")
            throw ExitCode.failure
        }
        
        // Generate default output path if not provided
        let outputPath: String
        if let output = output {
            outputPath = output
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let filename = URL(fileURLWithPath: input).lastPathComponent
            outputPath = "audio/output/output-\(timestamp)-\(filename)"
        }
        
        let config = Config(
            inputPath: input,
            outputPath: outputPath,
            serverUri: server,
            verbose: verbose
        )
        
        // Run the main workflow synchronously using RunLoop
        let state = WorkflowState()
        
        Task {
            do {
                try await Self.executeWorkflow(config: config)
            } catch {
                Logger.error("Fatal error: \(error.localizedDescription)")
                state.hasError = true
            }
            state.finished = true
        }
        
        while !state.finished {
            _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        
        if state.hasError {
            throw ExitCode.failure
        }
    }
    
    static func executeWorkflow(config: Config) async throws {
        Logger.info("Audio Stream Client")
        Logger.info("Input: \(config.inputPath)")
        Logger.info("Output: \(config.outputPath)")
        Logger.info("Server: \(config.serverUri)")
        
        // Initialize performance monitor
        let performance = PerformanceMonitor()
        let fileSize = try AudioFileManager.getFileSize(path: config.inputPath)
        performance.setFileSize(fileSize)
        
        // Connect to WebSocket server
        let ws = try WebSocketClient(uri: config.serverUri)
        try await ws.connect()
        
        defer {
            ws.close()
        }
        
        // Upload file
        performance.startUpload()
        let streamId = try await UploadManager.upload(ws: ws, filePath: config.inputPath)
        performance.endUpload()
        
        // Sleep 2 seconds after upload
        Logger.info("Upload successful, sleeping for 2 seconds...")
        try await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000)) // 2 seconds in nanoseconds
        
        // Download file
        performance.startDownload()
        try await DownloadManager.download(ws: ws, streamId: streamId, outputPath: config.outputPath, fileSize: fileSize)
        performance.endDownload()
        
        // Sleep 2 seconds after download
        Logger.info("Download successful, sleeping for 2 seconds...")
        try await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000)) // 2 seconds in nanoseconds
        
        // Verify integrity
        let verification = try VerificationModule.verify(originalPath: config.inputPath, downloadedPath: config.outputPath)
        
        // Report performance
        let report = performance.getReport()
        performance.printReport(report)
        
        // Exit with appropriate code
        if verification.passed {
            Logger.info("SUCCESS: Stream completed successfully")
        } else {
            Logger.error("FAILURE: File verification failed")
            throw ExitCode.failure
        }
    }
}
