import Foundation
#if canImport(Dispatch)
import Dispatch
#endif

/// Server entry point.
@main
struct ServerApp {
    static func main() {
        #if os(Windows)
        setvbuf(stdout, nil, Int32(_IONBF), 0)
        #endif

        var port = 8080
        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            if args[i] == "--port", i + 1 < args.count {
                port = Int(args[i + 1]) ?? 8080
                i += 1
            }
            i += 1
        }

        let mgr = StreamManager(cacheDir: "cache")
        let server = WebSocketServer(port: port, mgr: mgr)

        // Cleanup timer — every 30 seconds
        let cleanupTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        cleanupTimer.schedule(deadline: .now() + 30, repeating: 30)
        cleanupTimer.setEventHandler { mgr.cleanup() }
        cleanupTimer.resume()

        // Graceful shutdown
        #if !os(Windows)
        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigSource.setEventHandler {
            print("Shutting down...")
            server.stop()
            exit(0)
        }
        sigSource.resume()
        #endif

        server.start()

        print("Server running. Press Ctrl+C to stop.")
        let sem = DispatchSemaphore(value: 0)
        sem.wait()
    }
}
