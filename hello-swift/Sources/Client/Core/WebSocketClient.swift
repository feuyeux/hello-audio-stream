//
//  WebSocketClient.swift
//  Audio Stream Client
//
//  WebSocket client for audio streaming using URLSessionWebSocketTask.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AudioStreamCommon

/// WebSocket client for audio streaming using native URLSessionWebSocketTask
final class WebSocketClient: NSObject, @unchecked Sendable {
    private let uri: String
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    
    private let binaryQueue = AsyncStream<Data>.makeStream()
    private let textQueue = AsyncStream<String>.makeStream()
    private var isConnected = false
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    
    init(uri: String) {
        self.uri = uri
        super.init()
    }
    
    func connect() async throws {
        guard let url = URL(string: uri) else {
            throw NSError(domain: "WebSocketClient", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URI: \(uri)"
            ])
        }
        
        Logger.info("Connecting to \(uri)")
        
        webSocketTask = urlSession.webSocketTask(with: url)
        
        // Start receiving messages
        receiveMessage()
        
        // Resume the task to initiate connection
        webSocketTask?.resume()
        
        // Wait for connection to be established
        try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
        }
        
        Logger.info("Connected to server")
        
        // Wait for and consume CONNECTED message
        do {
            if let connectedMsg = try await receiveText(timeout: 1.0, expectedType: MessageType.CONNECTED.rawValue) {
                Logger.info("Received CONNECTED message from server")
            }
        } catch {
            // Ignore if no CONNECTED message
            Logger.debug("No CONNECTED message received")
        }
    }
    
    func sendText(_ message: WebSocketMessage) async throws {
        guard isConnected else {
            throw NSError(domain: "WebSocketClient", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Not connected"
            ])
        }
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "WebSocketClient", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to encode JSON"
            ])
        }
        
        Logger.debug("Sending: \(jsonString)")
        
        try await webSocketTask?.send(.string(jsonString))
    }
    
    func sendBinary(_ data: Data) async throws {
        guard isConnected else {
            throw NSError(domain: "WebSocketClient", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Not connected"
            ])
        }
        
        Logger.debug("Sending binary data: \(data.count) bytes")
        
        try await webSocketTask?.send(.data(data))
    }
    
    func receiveText(timeout: TimeInterval = 30, expectedType: String? = nil) async throws -> String? {
        for await text in textQueue.stream {
            // If expectedType is specified, filter messages by type
            if let expected = expectedType {
                if text.contains("\"type\":\"\(expected)\"") {
                    return text
                }
                // Skip messages that don't match expected type (e.g., CONNECTED)
                Logger.debug("Skipping non-matching message type, waiting for: \(expected)")
            } else {
                return text
            }
        }
        return nil
    }
    
    func receiveBinary(timeout: TimeInterval = 30) async throws -> Data? {
        for await data in binaryQueue.stream {
            return data
        }
        return nil
    }
    
    func close() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        binaryQueue.continuation.finish()
        textQueue.continuation.finish()
        isConnected = false
        Logger.info("Disconnected from server")
    }
    
    // MARK: - Private Methods
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] (result: Result<URLSessionWebSocketTask.Message, Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Logger.debug("Received text: \(text)")
                    self.textQueue.continuation.yield(text)
                    
                case .data(let data):
                    if data.count > 0 {
                        let hexPrefix = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
                        Logger.debug("Received binary data: \(data.count) bytes, first 16 bytes: \(hexPrefix)")
                    }
                    self.binaryQueue.continuation.yield(data)
                    
                @unknown default:
                    Logger.debug("Unknown message type received")
                }
                
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                Logger.error("WebSocket receive error: \(error)")
                self.binaryQueue.continuation.finish()
                self.textQueue.continuation.finish()
                self.isConnected = false
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Logger.info("WebSocket connection opened")
        isConnected = true
        connectionContinuation?.resume()
        connectionContinuation = nil
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Logger.info("WebSocket connection closed with code: \(closeCode.rawValue)")
        isConnected = false
        binaryQueue.continuation.finish()
        textQueue.continuation.finish()
    }
}

// MARK: - URLSessionDelegate

extension WebSocketClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Logger.error("WebSocket task error: \(error)")
            connectionContinuation?.resume(throwing: error)
            connectionContinuation = nil
            isConnected = false
        }
    }
}
