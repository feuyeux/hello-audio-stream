//
//  WebSocketClient.swift
//  Audio Stream Client
//
//  WebSocket client for audio streaming using SwiftNIO.
//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import AudioStreamCommon

/// WebSocket client for audio streaming using SwiftNIO
class WebSocketClient {
    private let uri: String
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let binaryQueue = AsyncStream<Data>.makeStream()
    private let textQueue = AsyncStream<String>.makeStream()
    private let connectedPromise: EventLoopPromise<Void>

    init(uri: String) {
        self.uri = uri
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.connectedPromise = group.next().makePromise()
    }

    func connect() async throws {
        guard let url = URL(string: uri) else {
            throw NSError(domain: "WebSocketClient", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid URI: \(uri)"
            ])
        }

        let scheme = url.scheme ?? "ws"
        let isSecure = scheme == "wss"
        let host = url.host ?? "localhost"
        let port = url.port ?? (isSecure ? 443 : 80)
        let path = url.path.isEmpty ? "/" : url.path

        Logger.info("Connecting to \(uri)")

        let key = generateWebSocketKey()

        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(.init(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandler(WebSocketUpgradeHandler(
                    connectedPromise: self.connectedPromise,
                    wsKey: key,
                    binaryContinuation: self.binaryQueue.continuation,
                    textContinuation: self.textQueue.continuation
                ))
            }

        do {
            channel = try bootstrap.connect(host: host, port: port).wait()

            // Send HTTP upgrade request as raw buffer
            var requestString = "GET \(path) HTTP/1.1\r\n"
            requestString += "Host: \(host):\(port)\r\n"
            requestString += "Upgrade: websocket\r\n"
            requestString += "Connection: Upgrade\r\n"
            requestString += "Sec-WebSocket-Key: \(key)\r\n"
            requestString += "Sec-WebSocket-Version: 13\r\n"
            requestString += "\r\n"

            if let ch = channel {
                var buffer = ch.allocator.buffer(capacity: requestString.utf8.count)
                buffer.writeString(requestString)
                try await ch.writeAndFlush(buffer).get()
            }

            // Wait for connection to be established
            try await withCheckedThrowingContinuation { continuation in
                connectedPromise.futureResult.whenComplete { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            Logger.info("Connected to server")
        } catch {
            Logger.error("Connection failed: \(error)")
            throw error
        }
    }

    func sendText(_ message: WebSocketMessage) async throws {
        guard let channel else {
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

        let frame = createWebSocketFrame(opcode: 0x01, payload: Array(jsonString.utf8))
        try await channel.writeAndFlush(frame)
    }

    func sendBinary(_ data: Data) async throws {
        guard let channel else {
            throw NSError(domain: "WebSocketClient", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Not connected"
            ])
        }

        Logger.debug("Sending binary data: \(data.count) bytes")

        let frame = createWebSocketFrame(opcode: 0x02, payload: Array(data))
        try await channel.writeAndFlush(frame)
    }

    private func createWebSocketFrame(opcode: UInt8, payload: [UInt8]) -> ByteBuffer {
        var buffer = channel!.allocator.buffer(capacity: payload.count + 10)

        // Generate mask
        var mask: [UInt8] = [0, 0, 0, 0]
        for i in 0..<4 {
            mask[i] = UInt8.random(in: 0...255)
        }

        // Mask the payload
        var maskedPayload = payload
        for i in 0..<payload.count {
            maskedPayload[i] = payload[i] ^ mask[i % 4]
        }

        // FIN + opcode
        buffer.writeInteger(UInt8(0x80 | opcode))

        // MASK bit + payload length
        let len = payload.count
        if len < 126 {
            buffer.writeInteger(UInt8(0x80 | UInt8(len)))
        } else if len < 65536 {
            buffer.writeInteger(UInt8(0x80 | 126))
            buffer.writeInteger(UInt16(len))
        } else {
            buffer.writeInteger(UInt8(0x80 | 127))
            buffer.writeInteger(UInt64(len))
        }

        // Mask
        for m in mask {
            buffer.writeInteger(m)
        }

        // Masked payload
        buffer.writeBytes(maskedPayload)

        return buffer
    }

    func receiveText() async throws -> String? {
        for await text in textQueue.stream {
            return text
        }
        return nil
    }

    func receiveBinary() async throws -> Data? {
        for await data in binaryQueue.stream {
            return data
        }
        return nil
    }

    func close() {
        channel?.close(promise: nil)
        binaryQueue.continuation.finish()
        textQueue.continuation.finish()
        do {
            try group.syncShutdownGracefully()
            Logger.info("Disconnected from server")
        } catch {
            Logger.error("Error during shutdown: \(error)")
        }
    }
}

// MARK: - WebSocket Upgrade Handler

private final class WebSocketUpgradeHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private enum State {
        case waitingUpgrade
        case websocketConnected
    }

    private let connectedPromise: EventLoopPromise<Void>
    private let wsKey: String
    private let binaryContinuation: AsyncStream<Data>.Continuation
    private let textContinuation: AsyncStream<String>.Continuation
    private var state: State = .waitingUpgrade
    private var responseBuffer = ""

    init(
        connectedPromise: EventLoopPromise<Void>,
        wsKey: String,
        binaryContinuation: AsyncStream<Data>.Continuation,
        textContinuation: AsyncStream<String>.Continuation
    ) {
        self.connectedPromise = connectedPromise
        self.wsKey = wsKey
        self.binaryContinuation = binaryContinuation
        self.textContinuation = textContinuation
    }

    func channelActive(context: ChannelHandlerContext) {
        // Connection established
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch state {
        case .waitingUpgrade:
            var buffer = unwrapInboundIn(data)
            if let data = buffer.readString(length: buffer.readableBytes) {
                responseBuffer += data
                // Check if we have a complete HTTP response
                if responseBuffer.contains("\r\n\r\n") {
                    handleUpgradeResponse(context: context)
                }
            }

        case .websocketConnected:
            // Forward raw bytes to WebSocket handler
            context.fireChannelRead(data)
        }
    }

    private func handleUpgradeResponse(context: ChannelHandlerContext) {
        guard let responseEnd = responseBuffer.range(of: "\r\n\r\n") else {
            return
        }

        let headerText = String(responseBuffer[responseBuffer.startIndex..<responseEnd.lowerBound])
        responseBuffer = String(responseBuffer[responseEnd.upperBound...])

        // Parse HTTP response
        let lines = headerText.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            failUpgrade(context: context, message: "Invalid HTTP response")
            return
        }

        // Check for "HTTP/1.1 101 Switching Protocols"
        if !statusLine.contains("101") && !statusLine.contains("Switching") {
            failUpgrade(context: context, message: "Unexpected HTTP response: \(statusLine)")
            return
        }

        // Check for Sec-WebSocket-Accept header
        var acceptKey: String?
        for line in lines where line.lowercased().starts(with: "sec-websocket-accept:") {
            acceptKey = line.dropFirst("sec-websocket-accept:".count).trimmingCharacters(in: .whitespaces)
            break
        }

        guard let receivedKey = acceptKey else {
            failUpgrade(context: context, message: "Missing Sec-WebSocket-Accept header")
            return
        }

        let expected = computeAcceptKey(wsKey)
        if receivedKey != expected {
            failUpgrade(context: context, message: "Invalid Sec-WebSocket-Accept")
            return
        }

        // Upgrade successful - add WebSocket frame handler
        state = .websocketConnected
        context.pipeline.addHandler(WebSocketFrameHandler(
            binaryContinuation: binaryContinuation,
            textContinuation: textContinuation
        ), position: .last).whenComplete { result in
            if case .success = result {
                self.connectedPromise.succeed(())
            } else {
                self.failUpgrade(context: context, message: "Failed to add WebSocket handler")
            }
        }
    }

    private func failUpgrade(context: ChannelHandlerContext, message: String) {
        Logger.error("WebSocket upgrade failed: \(message)")
        connectedPromise.fail(NSError(domain: "WebSocketClient", code: 4, userInfo: [
            NSLocalizedDescriptionKey: message
        ]))
        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.error("WebSocket upgrade error: \(error)")
        connectedPromise.fail(error)
        context.close(promise: nil)
    }
}

// MARK: - WebSocket Frame Handler

private final class WebSocketFrameHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let binaryContinuation: AsyncStream<Data>.Continuation
    private let textContinuation: AsyncStream<String>.Continuation

    init(
        binaryContinuation: AsyncStream<Data>.Continuation,
        textContinuation: AsyncStream<String>.Continuation
    ) {
        self.binaryContinuation = binaryContinuation
        self.textContinuation = textContinuation
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)

        while buffer.readableBytes >= 2 {
            // Read frame header
            guard let byte1 = buffer.readInteger(as: UInt8.self),
                  let byte2 = buffer.readInteger(as: UInt8.self) else {
                break
            }

            let fin = (byte1 & 0x80) != 0
            let opcode = byte1 & 0x0F
            let masked = (byte2 & 0x80) != 0
            var payloadLength = Int(byte2 & 0x7F)

            // Check if we have enough data for the frame
            if masked {
                if payloadLength == 126 {
                    guard buffer.readableBytes >= 2,
                          let extendedLength = buffer.readInteger(as: UInt16.self) else { break }
                    payloadLength = Int(extendedLength)
                } else if payloadLength == 127 {
                    guard buffer.readableBytes >= 8,
                          let extendedLength = buffer.readInteger(as: UInt64.self) else { break }
                    payloadLength = Int(extendedLength)
                }
            }

            // Check if we have enough data for payload and mask
            let maskSize = masked ? 4 : 0
            guard buffer.readableBytes >= payloadLength + maskSize else {
                // Not enough data, put bytes back and wait
                buffer.moveReaderIndex(to: buffer.readerIndex - 2)
                break
            }

            // Read mask if present
            var mask: [UInt8] = []
            if masked {
                mask = [UInt8](repeating: 0, count: 4)
                for i in 0..<4 {
                    guard let byte = buffer.readInteger(as: UInt8.self) else {
                        buffer.moveReaderIndex(to: buffer.readerIndex - 2)
                        return
                    }
                    mask[i] = byte
                }
            }

            // Read payload
            guard var payload = buffer.readBytes(length: payloadLength) else {
                buffer.moveReaderIndex(to: buffer.readerIndex - 2)
                return
            }

            // Unmask if needed
            if masked {
                for i in 0..<payload.count {
                    payload[i] = payload[i] ^ mask[i % 4]
                }
            }

            // Handle opcode
            switch opcode {
            case 0x01: // Text
                if let text = String(data: Data(payload), encoding: .utf8) {
                    Logger.debug("Received: \(text)")
                    textContinuation.yield(text)
                }

            case 0x02: // Binary
                Logger.debug("Received binary data: \(payload.count) bytes")
                binaryContinuation.yield(Data(payload))

            case 0x08: // Close
                Logger.info("Server closed connection")
                context.close(promise: nil)
                return

            case 0x09: // Ping
                sendPong(context: context, payload: payload)

            case 0x0A: // Pong
                // Ignore pong
                break

            default:
                break
            }

            // If not fin, continue receiving fragmented frames
            if !fin {
                continue
            }
        }
    }

    private func sendPong(context: ChannelHandlerContext, payload: [UInt8]) {
        var buffer = context.channel.allocator.buffer(capacity: payload.count + 2)
        buffer.writeInteger(UInt8(0x8A)) // Pong with FIN
        let len = payload.count
        if len < 126 {
            buffer.writeInteger(UInt8(UInt8(len)))
        } else if len < 65536 {
            buffer.writeInteger(UInt8(126))
            buffer.writeInteger(UInt16(len))
        } else {
            buffer.writeInteger(UInt8(127))
            buffer.writeInteger(UInt64(len))
        }
        buffer.writeBytes(payload)
        context.writeAndFlush(NIOAny(buffer), promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        binaryContinuation.finish()
        textContinuation.finish()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        Logger.error("WebSocket error: \(error)")
        context.close(promise: nil)
    }
}

// MARK: - Helper Functions

private func generateWebSocketKey() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<16 {
        bytes[i] = UInt8.random(in: 0...255)
    }
    return Data(bytes).base64EncodedString()
}

private func computeAcceptKey(_ key: String) -> String {
    let guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let combined = key + guid
    guard let data = combined.data(using: .utf8) else {
        return ""
    }
    let hash = data.sha1()
    return hash.base64EncodedString()
}

extension Data {
    func sha1() -> Data {
        // Simple SHA1 implementation for WebSocket key computation
        var hash = [UInt8](repeating: 0, count: 20)
        var workingData = Array(self)
        var blockSize = 64

        // Append padding
        workingData.append(0x80)
        while workingData.count % blockSize != 56 {
            workingData.append(0)
        }

        // Append original length in bits (64-bit big-endian)
        var bitLength = UInt64(self.count) * 8
        for _ in 0..<8 {
            workingData.append(UInt8((bitLength >> 56) & 0xFF))
            bitLength <<= 8
        }

        // Process blocks
        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xEFCDAB89
        var h2: UInt32 = 0x98BADCFE
        var h3: UInt32 = 0x10325476
        var h4: UInt32 = 0xC3D2E1F0

        for blockStart in stride(from: 0, to: workingData.count, by: blockSize) {
            var w = [UInt32](repeating: 0, count: 80)

            for i in 0..<16 {
                w[i] = UInt32(workingData[blockStart + i * 4]) << 24 |
                       UInt32(workingData[blockStart + i * 4 + 1]) << 16 |
                       UInt32(workingData[blockStart + i * 4 + 2]) << 8 |
                       UInt32(workingData[blockStart + i * 4 + 3])
            }

            for i in 16..<80 {
                let temp = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
                w[i] = (temp << 1) | (temp >> 31)
            }

            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4

            for i in 0..<80 {
                var f: UInt32
                var k: UInt32

                switch i {
                case 0..<20:
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                case 20..<40:
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                case 40..<60:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                default:
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }

                let temp = ((a << 5) | (a >> 27)) &+ f &+ e &+ k &+ w[i]
                e = d
                d = c
                c = (b << 30) | (b >> 2)
                b = a
                a = temp
            }

            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
        }

        h0 = h0.bigEndian
        h1 = h1.bigEndian
        h2 = h2.bigEndian
        h3 = h3.bigEndian
        h4 = h4.bigEndian

        var result = Data(capacity: 20)
        Swift.withUnsafeBytes(of: h0) { result.append(contentsOf: $0) }
        Swift.withUnsafeBytes(of: h1) { result.append(contentsOf: $0) }
        Swift.withUnsafeBytes(of: h2) { result.append(contentsOf: $0) }
        Swift.withUnsafeBytes(of: h3) { result.append(contentsOf: $0) }
        Swift.withUnsafeBytes(of: h4) { result.append(contentsOf: $0) }

        return result
    }
}
