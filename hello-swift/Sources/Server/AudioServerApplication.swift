//
//  AudioServerApplication.swift
//  Audio Stream Server
//
//  Main entry point for Swift audio stream server.
//

import Foundation
import Dispatch

@main
struct AudioServerApplication {
    static func main() {
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
        let streamManager = StreamManager.getInstance()
        let memoryPool = MemoryPoolManager.getInstance()

        // Create and start WebSocket server
        let server = AudioWebSocketServer(port: port, path: path,
                                  streamManager: streamManager,
                                  memoryPool: memoryPool)

        // Handle graceful shutdown
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler {
            print("Shutting down server...")
            server.stop()
            exit(0)
        }
        signalSource.resume()

        // Start server
        server.start()

        // Keep running
        dispatchMain()
    }
}
