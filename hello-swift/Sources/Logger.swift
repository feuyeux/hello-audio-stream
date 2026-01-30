import Foundation

/// Simple logging utility
public class Logger {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    nonisolated(unsafe) private static var verboseEnabled = false
    
    public static func setVerbose(_ enabled: Bool) {
        verboseEnabled = enabled
    }
    
    public static func debug(_ message: String) {
        if verboseEnabled {
            log(level: "debug", message: message)
        }
    }
    
    public static func info(_ message: String) {
        log(level: "info", message: message)
    }
    
    public static func warn(_ message: String) {
        log(level: "warn", message: message)
    }
    
    public static func error(_ message: String) {
        log(level: "error", message: message)
    }
    
    private static func log(level: String, message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(level)] \(message)")
    }
}
