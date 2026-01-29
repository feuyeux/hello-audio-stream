import Foundation
import AudioStreamCommon

/// Error handler for centralized error management
class ErrorHandler {
    /// Handle and log errors
    static func handle(_ error: Error, context: String) {
        Logger.error("[\(context)] Error: \(error.localizedDescription)")
    }
    
    /// Create a domain-specific error
    static func createError(domain: String, code: Int, message: String) -> NSError {
        return NSError(domain: domain, code: code, 
                      userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    /// Validate file existence
    static func validateFileExists(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw createError(domain: "ErrorHandler", code: 1, 
                            message: "File does not exist: \(path)")
        }
    }
    
    /// Validate URL format
    static func validateURL(_ urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw createError(domain: "ErrorHandler", code: 2, 
                            message: "Invalid URL: \(urlString)")
        }
        return url
    }
}
