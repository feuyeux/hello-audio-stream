//
//  WebSocketMessageHandler.swift
//  Audio Stream Server
//
//  Handles WebSocket message processing and routing.
//  Extracted from WebSocketServer for better separation of concerns.
//

import Foundation
import AudioStreamCommon

/// Message handler for processing WebSocket messages
class WebSocketMessageHandler: @unchecked Sendable {
    private let streamManager: StreamManager
    
    init(streamManager: StreamManager) {
        self.streamManager = streamManager
    }
    
    /// Process a text (JSON) control message
    func handleTextMessage(message: String, sendResponse: @escaping (AudioStreamCommon.WebSocketMessage) -> Void, sendBinary: @escaping (Data) -> Void) {
        guard let data = message.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AudioStreamCommon.WebSocketMessage.self, from: data) else {
            Logger.info("Invalid JSON message")
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Invalid JSON format"))
            return
        }

        // Use enum for type checking
        guard let msgType = decoded.messageTypeEnum else {
            Logger.warn("Unknown message type: \(decoded.type)")
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Unknown message type: \(decoded.type)"))
            return
        }

        switch msgType {
        case .START:
            handleStart(data: decoded, sendResponse: sendResponse)

        case .STOP:
            handleStop(data: decoded, sendResponse: sendResponse)

        case .GET:
            handleGet(data: decoded, sendResponse: sendResponse, sendBinary: sendBinary)

        default:
            Logger.warn("Unhandled message type: \(decoded.type)")
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Unhandled message type: \(decoded.type)"))
        }
    }
    
    /// Handle binary audio data
    func handleBinaryMessage(streamId: String, data: Data) {
        Logger.debug("Received \(data.count) bytes of binary data for stream \(streamId)")
        _ = streamManager.writeChunk(streamId: streamId, data: data)
    }
    
    /// Handle START message (create new stream)
    private func handleStart(data: AudioStreamCommon.WebSocketMessage, sendResponse: @escaping (AudioStreamCommon.WebSocketMessage) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Missing streamId"))
            return
        }

        if streamManager.createStream(streamId: streamId) {
            sendResponse(AudioStreamCommon.WebSocketMessage.started(
                streamId: streamId,
                message: "Stream started successfully"
            ))
            Logger.info("Stream started: \(streamId)")
        } else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Failed to create stream: \(streamId)"))
        }
    }
    
    /// Handle STOP message (finalize stream)
    private func handleStop(data: AudioStreamCommon.WebSocketMessage, sendResponse: @escaping (AudioStreamCommon.WebSocketMessage) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Missing streamId"))
            return
        }

        if streamManager.finalizeStream(streamId: streamId) {
            sendResponse(AudioStreamCommon.WebSocketMessage.stopped(
                streamId: streamId,
                message: "Stream finalized successfully"
            ))
            Logger.info("Stream finalized: \(streamId)")
        } else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Failed to finalize stream: \(streamId)"))
        }
    }
    
    /// Handle GET message (read stream data)
    private func handleGet(data: AudioStreamCommon.WebSocketMessage, sendResponse: @escaping (AudioStreamCommon.WebSocketMessage) -> Void, sendBinary: @escaping (Data) -> Void) {
        guard let streamId = data.streamId, !streamId.isEmpty else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Missing streamId"))
            return
        }

        let offset = data.offset ?? 0
        let length = data.length ?? 65536

        let chunkData = streamManager.readChunk(streamId: streamId, offset: offset, length: Int(length))

        if !chunkData.isEmpty {
            sendBinary(chunkData)
            Logger.debug("Sent \(chunkData.count) bytes for stream \(streamId) at offset \(offset)")
        } else {
            sendResponse(AudioStreamCommon.WebSocketMessage.error(message: "Failed to read from stream: \(streamId)"))
        }
    }
}
