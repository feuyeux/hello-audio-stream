
//
//  AudioServerApplication.swift
//  Audio Stream Server
//
//  Main entry point for Swift audio stream server.
//

import Foundation
import AudioStreamCommon
#if canImport(Dispatch)
import Dispatch
#endif
#if os(Windows)
import WinSDK
#endif

@main
struct AudioServerApplication {
    static func main() {
        #if os(Windows)
        // Disable stdout buffering
        setbuf(stdout, nil)
        #endif
        // Parse command-line arguments
        var port = 8080
        var path = "/audio"
        
        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            if args[i] == "--port" && i + 1 < args.count {
                port = Int(args[i + 1]) ?? 8080
                i += 1
            } else if args[i] == "--path" && i + 1 < args.count {
                path = args[i + 1]
                i += 1
            }
            i += 1
        }
        
        print("Starting Audio Server on port \(port) with path \(path)")

        // Get singleton instances
        let streamManager = StreamManager.shared

        // Enable verbose logging for debugging
        Logger.setVerbose(true)

        // Create and start WebSocket server
        let server = AudioWebSocketServer(port: port, path: path,
                                  streamManager: streamManager)

        // Handle graceful shutdown if possible
        #if !os(Windows)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler {
            print("Shutting down server...")
            server.stop()
            exit(0)
        }
        signalSource.resume()
        #endif

        // Start server
        Logger.info("DEBUG: Calling server.start()")
        server.start()
        Logger.info("DEBUG: server.start() returned")

        // Keep running
        Logger.info("Server running. Waiting for connections...")
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait()
    }
}
