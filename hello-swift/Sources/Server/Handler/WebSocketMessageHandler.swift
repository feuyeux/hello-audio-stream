//
//  WebSocketMessageHandler.swift
//  Audio Stream Server
//
//  Handles WebSocket message processing and routing.
//  Extracted from WebSocketServer for better separation of concerns.
//

import Foundation
import AudioStreamCommon

/// WebSocket message types
struct WebSocketMessage: Codable {
    let type: String
    let streamId: String?
    let offset: Int64?
    let length: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type
        case streamId = "streamId"
        case offset
        case length
        case message
    }
}

/// Message handler for processing WebSocket messages
class WebSocketMessageHandler {
    private let streamManager: StreamManager
    
    init(streamManager: StreamManager) {
        self.streamManager = streamManager
    }
    
    /// Process a text (JSON) control message
    func handleTextMessage(message: String, sendResponse: @escaping (WebSocketMessage) -> Void, sendBinary: @escaping (Data) -> Void) {
        guard let data = message.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(WebSocketMessage.self, from: data) else {
            Logger.info("Invalid JSON message")
            sendError(message: "Invalid JSON format", sendResponse: sendResponse)
            return
        }

        switch decoded.type {
        case "START":
            handleStart(data: decoded, sendResponse: sendResponse)

        case "STOP":
            handleStop(data: decoded, sendResponse: sendResponse)

        case "GET":
            handleGet(data: decoded, sendResponse: sendResponse, sendBinary: sendBinary)

        default:
            Logger.warn("Unknown message type: \(decoded.type)")
            sendError(message: "Unknown message type: \(decoded.type)", sendResponse: sendResponse)
        }
    }
    
    /// Handle binary audio data
    func handleBinaryMessage(streamId: String, data: Data) {
        Logger.debug("Received \(data.count) bytes of binary data for stream \(streamId)")
        _ = streamManager.writeChunk(streamId: streamId, data: data)
    }
    
    /// Handle START message (create new stream)
    private func handleStart(data: WebSocketMessage, sendResponse: @escaping (WebSocketMessage) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendError(message: "Missing streamId", sendResponse: sendResponse)
            return
        }

        if streamManager.createStream(streamId: streamId) {
            let response = WebSocketMessage(
                type: MessageType.STARTED.rawValue,
                streamId: streamId,
                offset: nil,
                length: nil,
                message: "Stream started successfully"
            )
            sendResponse(response)
            Logger.info("Stream started: \(streamId)")
        } else {
            sendError(message: "Failed to create stream: \(streamId)", sendResponse: sendResponse)
        }
    }
    
    /// Handle STOP message (finalize stream)
    private func handleStop(data: WebSocketMessage, sendResponse: @escaping (WebSocketMessage) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendError(message: "Missing streamId", sendResponse: sendResponse)
            return
        }

        if streamManager.finalizeStream(streamId: streamId) {
            let response = WebSocketMessage(
                type: MessageType.STOPPED.rawValue,
                streamId: streamId,
                offset: nil,
                length: nil,
                message: "Stream finalized successfully"
            )
            sendResponse(response)
            Logger.info("Stream finalized: \(streamId)")
        } else {
            sendError(message: "Failed to finalize stream: \(streamId)", sendResponse: sendResponse)
        }
    }
    
    /// Handle GET message (read stream data)
    private func handleGet(data: WebSocketMessage, sendResponse: @escaping (WebSocketMessage) -> Void, sendBinary: @escaping (Data) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendError(message: "Missing streamId", sendResponse: sendResponse)
            return
        }

        let offset = data.offset ?? 0
        let length = data.length ?? 65536

        let chunkData = streamManager.readChunk(streamId: streamId, offset: offset, length: Int(length))

        if !chunkData.isEmpty {
            sendBinary(chunkData)
            Logger.debug("Sent \(chunkData.count) bytes for stream \(streamId) at offset \(offset)")
        } else {
            sendError(message: "Failed to read from stream: \(streamId)", sendResponse: sendResponse)
        }
    }
    
    /// Send an error message
    private func sendError(message: String, sendResponse: @escaping (WebSocketMessage) -> Void) {
        let response = WebSocketMessage(
            type: "ERROR",
            streamId: nil,
            offset: nil,
            length: nil,
            message: message
        )
        sendResponse(response)
        Logger.error("Sent error: \(message)")
    }
}
