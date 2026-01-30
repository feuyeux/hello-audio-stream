//
//  AudioWebSocketServer.swift
//  Audio Stream Server
//
//  WebSocket server for audio streaming using SwiftNIO.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import AudioStreamCommon

/// WebSocket server for handling audio stream uploads and downloads.
class AudioWebSocketServer {
    private let port: Int
    private let path: String
    private let streamManager: StreamManager
    private let memoryPool: MemoryPoolManager
    private let messageHandler: WebSocketMessageHandler
    private var channel: Channel?
    private let group: MultiThreadedEventLoopGroup
    
    /// Create a new WebSocket server.
    init(port: Int = 8080, path: String = "/audio",
         streamManager: StreamManager? = nil,
         memoryPool: MemoryPoolManager? = nil) {
        self.port = port
        self.path = path
        self.streamManager = streamManager ?? StreamManager.getInstance()
        self.memoryPool = memoryPool ?? MemoryPoolManager.getInstance()
        self.messageHandler = WebSocketMessageHandler(streamManager: self.streamManager)
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        Logger.info("AudioWebSocketServer initialized on port \(port)\(path)")
    }
    
    /// Start the WebSocket server.
    func start() {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = HTTPHandler(path: self.path)
                let websocketUpgrader = NIOWebSocketServerUpgrader(
                    shouldUpgrade: { (channel: Channel, head: HTTPRequestHead) in
                        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                    },
                    upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
                        channel.pipeline.addHandler(WebSocketHandler(
                            messageHandler: self.messageHandler,
                            streamManager: self.streamManager
                        ))
                    }
                )
                
                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: (
                        upgraders: [websocketUpgrader],
                        completionHandler: { _ in }
                    )
                ).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        do {
            channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            Logger.info("WebSocket server started on ws://0.0.0.0:\(port)\(path)")
        } catch {
            Logger.error("Failed to start WebSocket server: \(error)")
        }
    }
    
    /// Stop the WebSocket server.
    func stop() {
        do {
            try channel?.close().wait()
            try group.syncShutdownGracefully()
            Logger.info("WebSocket server stopped")
        } catch {
            Logger.error("Error stopping server: \(error)")
        }
    }
}

/// HTTP handler for WebSocket upgrade
private final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let path: String
    
    init(path: String) {
        self.path = path
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            // Check if this is a WebSocket upgrade request
            let isWebSocketUpgrade = head.headers["Upgrade"].contains { $0.lowercased() == "websocket" }
            
            if !isWebSocketUpgrade && head.uri != path {
                let headers = HTTPHeaders([("Content-Length", "9")])
                context.write(wrapOutboundOut(.head(HTTPResponseHead(
                    version: head.version,
                    status: .notFound,
                    headers: headers
                ))), promise: nil)
                var buffer = context.channel.allocator.buffer(capacity: 9)
                buffer.writeString("Not Found")
                context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            }
            // For WebSocket upgrades, let the pipeline handle it
            context.fireChannelRead(data)
        case .body, .end:
            context.fireChannelRead(data)
        }
    }
}

/// WebSocket message handler
private final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    
    private let messageHandler: WebSocketMessageHandler
    private let streamManager: StreamManager
    private var activeStreamId: String?
    
    init(messageHandler: WebSocketMessageHandler, streamManager: StreamManager) {
        self.messageHandler = messageHandler
        self.streamManager = streamManager
    }
    
    func channelActive(context: ChannelHandlerContext) {
        Logger.info("Client connected")
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        Logger.info("Client disconnected")
        if let streamId = activeStreamId {
            activeStreamId = nil
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        
        switch frame.opcode {
        case .text:
            var data = frame.unmaskedData
            if let text = data.readString(length: data.readableBytes) {
                handleTextMessage(context: context, text: text)
            }
        case .binary:
            var data = frame.unmaskedData
            if let bytes = data.readBytes(length: data.readableBytes) {
                handleBinaryMessage(context: context, data: bytes)
            }
        case .connectionClose:
            context.close(promise: nil)
        case .ping:
            var frameData = frame.data
            let pongFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
            context.writeAndFlush(wrapOutboundOut(pongFrame), promise: nil)
        default:
            break
        }
    }
    
    private func handleTextMessage(context: ChannelHandlerContext, text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            sendError(context: context, message: "Invalid JSON format")
            return
        }
        
        switch type {
        case "START":
            guard let streamId = json["streamId"] as? String else {
                sendError(context: context, message: "Missing streamId")
                return
            }
            handleStart(context: context, streamId: streamId)
            
        case "STOP":
            guard let streamId = json["streamId"] as? String else {
                sendError(context: context, message: "Missing streamId")
                return
            }
            handleStop(context: context, streamId: streamId)
            
        case "GET":
            guard let streamId = json["streamId"] as? String else {
                sendError(context: context, message: "Missing streamId")
                return
            }
            let offset = json["offset"] as? Int ?? 0
            let length = json["length"] as? Int ?? 65536
            handleGet(context: context, streamId: streamId, offset: offset, length: length)
            
        default:
            sendError(context: context, message: "Unknown message type: \(type)")
        }
    }
    
    private func handleBinaryMessage(context: ChannelHandlerContext, data: [UInt8]) {
        guard let streamId = activeStreamId else {
            sendError(context: context, message: "No active stream for binary data")
            return
        }
        
        Logger.debug("Received \(data.count) bytes of binary data for stream \(streamId)")
        _ = streamManager.writeChunk(streamId: streamId, data: Data(data))
    }
    
    private func handleStart(context: ChannelHandlerContext, streamId: String) {
        if streamManager.createStream(streamId: streamId) {
            activeStreamId = streamId
            let response: [String: Any] = [
                "type": "STARTED",
                "streamId": streamId,
                "message": "Stream started successfully"
            ]
            sendJSON(context: context, json: response)
            Logger.info("Stream started: \(streamId)")
        } else {
            sendError(context: context, message: "Failed to create stream: \(streamId)")
        }
    }
    
    private func handleStop(context: ChannelHandlerContext, streamId: String) {
        if streamManager.finalizeStream(streamId: streamId) {
            activeStreamId = nil
            let response: [String: Any] = [
                "type": "STOPPED",
                "streamId": streamId,
                "message": "Stream finalized successfully"
            ]
            sendJSON(context: context, json: response)
            Logger.info("Stream finalized: \(streamId)")
        } else {
            sendError(context: context, message: "Failed to finalize stream: \(streamId)")
        }
    }
    
    private func handleGet(context: ChannelHandlerContext, streamId: String, offset: Int, length: Int) {
        let chunkData = streamManager.readChunk(streamId: streamId, offset: Int64(offset), length: length)
        
        if !chunkData.isEmpty {
            var buffer = context.channel.allocator.buffer(capacity: chunkData.count)
            buffer.writeBytes(chunkData)
            let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
            context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
            Logger.debug("Sent \(chunkData.count) bytes for stream \(streamId) at offset \(offset)")
        } else {
            sendError(context: context, message: "Failed to read from stream: \(streamId)")
        }
    }
    
    private func sendJSON(context: ChannelHandlerContext, json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        
        var buffer = context.channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        context.writeAndFlush(wrapOutboundOut(frame), promise: nil)
    }
    
    private func sendError(context: ChannelHandlerContext, message: String) {
        let response: [String: Any] = [
            "type": "ERROR",
            "message": message
        ]
        sendJSON(context: context, json: response)
        Logger.error("Sent error to client: \(message)")
    }
}
