import Foundation
@preconcurrency import FoundationNetworking
import AudioStreamCommon

/// WebSocket client for audio streaming
class WebSocketClient {
    private let url: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    
    init(uri: String) throws {
        guard let url = URL(string: uri) else {
            throw NSError(domain: "WebSocketClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URI"])
        }
        self.url = url
        self.session = URLSession(configuration: .default)
    }
    
    func connect() async throws {
        Logger.info("Connecting to \(url.absoluteString)")
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        Logger.info("Connected to server")
    }
    
    func sendText(_ message: WebSocketMessage) async throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WebSocketClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON"])
        }

        Logger.debug("Sending: \(jsonString)")
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await webSocketTask?.send(message)
    }
    
    func sendBinary(_ data: Data) async throws {
        Logger.debug("Sending binary data: \(data.count) bytes")
        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }
    
    func receiveText() async throws -> String? {
        guard let webSocketTask = webSocketTask else {
            return nil
        }
        
        do {
            let message = try await webSocketTask.receive()
            
            switch message {
            case .string(let text):
                Logger.debug("Received: \(text)")
                return text
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    Logger.debug("Received: \(text)")
                    return text
                }
                return nil
            @unknown default:
                return nil
            }
        } catch {
            Logger.error("Error receiving text: \(error)")
            throw error
        }
    }
    
    func receiveBinary() async throws -> Data? {
        guard let webSocketTask = webSocketTask else {
            return nil
        }
        
        do {
            let message = try await webSocketTask.receive()
            
            switch message {
            case .data(let data):
                Logger.debug("Received binary data: \(data.count) bytes")
                return data
            case .string:
                return nil
            @unknown default:
                return nil
            }
        } catch {
            Logger.error("Error receiving binary: \(error)")
            throw error
        }
    }
    
    func close() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        Logger.info("Disconnected from server")
    }
}
