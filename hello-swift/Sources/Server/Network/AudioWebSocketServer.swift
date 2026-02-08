
import Foundation
#if os(Windows)
import WinSDK
#endif
import AudioStreamCommon

#if os(Windows)
/// Simple atomic counter for thread-safe connection ID generation
final class AtomicCounter: @unchecked Sendable {
    private var value: UInt32 = 0
    private let lock = NSLock()

    func incrementAndGet() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

/// A simple, dependency-free WebSocket server implementation using WinSDK (Winsock).
class AudioWebSocketServer: @unchecked Sendable {
    // ... (Same content as previous Write)
    private let port: Int
    private let path: String
    private let messageHandler: WebSocketMessageHandler
    private let streamManager: StreamManager
    private let memoryPool: MemoryPoolManager
    
    // WinSDK socket type alias
    typealias SOCKET = UInt64 
    private var listenSocket: SOCKET = 0xFFFFFFFFFFFFFFFF // INVALID_SOCKET
    private var isRunning = false
    
    // Winsock initialization state
    nonisolated(unsafe) private static var isWinsockInitialized = false
    
    init(port: Int = 8080, path: String = "/audio", streamManager: StreamManager, memoryPool: MemoryPoolManager) {
        self.port = port
        self.path = path
        self.streamManager = streamManager
        self.memoryPool = memoryPool
        self.messageHandler = WebSocketMessageHandler(streamManager: streamManager)
        
        if !AudioWebSocketServer.isWinsockInitialized {
            var wsaData = WSAData()
            let result = WSAStartup(UInt16(0x0202), &wsaData)
            if result == 0 {
                AudioWebSocketServer.isWinsockInitialized = true
            } else {
                Logger.error("WSAStartup failed: \(result)")
            }
        }
    }
    
    deinit {
        stop()
    }
    
    func start() {
        guard AudioWebSocketServer.isWinsockInitialized else {
            Logger.error("Winsock not initialized")
            return
        }
        
        listenSocket = WinSDK.socket(Int32(AF_INET), Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
        if listenSocket == 0xFFFFFFFFFFFFFFFF {
            Logger.error("Failed to create socket: \(WSAGetLastError())")
            return
        }
        
        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.S_un.S_addr = 0 // INADDR_ANY (0)
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                WinSDK.bind(listenSocket, sockaddrPtr, Int32(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if bindResult == -1 {
            Logger.error("Failed to bind socket: \(WSAGetLastError())")
            WinSDK.closesocket(listenSocket)
            return
        }
        
        if WinSDK.listen(listenSocket, SOMAXCONN) == -1 {
            Logger.error("Failed to listen: \(WSAGetLastError())")
            WinSDK.closesocket(listenSocket)
            return
        }
        
        isRunning = true
        Logger.info("WinSDK WebSocket Server started on port \(port)")
        Logger.info("DEBUG: AudioWebSocketServer.start launching accept loop")
        
        // Accept loop
        Task.detached { [weak self] in
            Logger.info("DEBUG: Accept loop task started")
            self?.acceptLoop()
            Logger.info("DEBUG: Accept loop task ended")
        }
        Logger.info("DEBUG: AudioWebSocketServer.start returning")
    }
    
    func stop() {
        isRunning = false
        if listenSocket != 0xFFFFFFFFFFFFFFFF {
            WinSDK.closesocket(listenSocket)
            listenSocket = 0xFFFFFFFFFFFFFFFF
        }
    }
    
    private func acceptLoop() {
        while isRunning {
            let clientSocket = WinSDK.accept(listenSocket, nil, nil)
            if clientSocket == 0xFFFFFFFFFFFFFFFF {
                if isRunning {
                    Logger.error("Accept failed: \(WSAGetLastError())")
                }
                continue
            }
            
            // Set socket timeout to prevent blocking forever (30 seconds)
            /*
            var timeout = WinSDK.timeval()
            timeout.tv_sec = 30
            timeout.tv_usec = 0
            let timeoutSize = Int32(MemoryLayout<WinSDK.timeval>.size)
            withUnsafePointer(to: &timeout) { timeoutPtr in
                timeoutPtr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<WinSDK.timeval>.size) { charPtr in
                    WinSDK.setsockopt(clientSocket, WinSDK.SOL_SOCKET, WinSDK.SO_RCVTIMEO, 
                                    charPtr, timeoutSize)
                }
            }
            */
            
            // Handle client in a detached Task
            Task.detached { [weak self] in
                guard let self = self else { return }
                let connection = WebSocketConnection(socket: clientSocket, messageHandler: self.messageHandler, path: self.path)
                connection.start()
            }
        }
    }
}

/// Represents a single WebSocket connection
class WebSocketConnection: @unchecked Sendable {
    // WinSDK socket type alias
    typealias SOCKET = UInt64 

    private let socket: SOCKET
    private let messageHandler: WebSocketMessageHandler
    private let path: String
    private var isConnected = false
    private var activeStreamId: String?
    private var pendingData: [UInt8] = []

    private func processData(data: Data) {
        pendingData.append(contentsOf: [UInt8](data))
        Logger.debug("processData appended \(data.count) bytes. Total pending: \(pendingData.count)")
        
        while true {
            guard pendingData.count >= 2 else { 
                Logger.debug("Not enough data for header")
                return 
            }
            
            // Frame Header
            let byte1 = pendingData[0]
            let byte2 = pendingData[1]
            
            let opcode = byte1 & 0x0F
            let masked = (byte2 & 0x80) != 0
            var payloadLen = UInt64(byte2 & 0x7F)
            
            var headerSize = 2
            
            if payloadLen == 126 {
                guard pendingData.count >= 4 else { return }
                let high = UInt64(pendingData[2])
                let low = UInt64(pendingData[3])
                payloadLen = (high << 8) | low
                headerSize += 2
            } else if payloadLen == 127 {
                guard pendingData.count >= 10 else { return }
                payloadLen = 0 
                for i in 0..<8 {
                    payloadLen = (payloadLen << 8) | UInt64(pendingData[2+i])
                }
                headerSize += 8
            }
            
            var maskingKey = [UInt8](repeating: 0, count: 4)
            if masked {
                guard pendingData.count >= headerSize + 4 else { return }
                for i in 0..<4 {
                    maskingKey[i] = pendingData[headerSize + i]
                }
                headerSize += 4
            }
            
            guard UInt64(pendingData.count) >= UInt64(headerSize) + payloadLen else { return }
            
            // Extract Payload
            let payloadStart = headerSize
            let payloadEnd = payloadStart + Int(payloadLen)
            var payload = [UInt8](pendingData[payloadStart..<payloadEnd])
            
            if masked {
                for i in 0..<payload.count {
                    payload[i] ^= maskingKey[i % 4]
                }
            }
            
            // Process Frame
            switch opcode {
            case 1: // Text
                if let text = String(bytes: payload, encoding: .utf8) {
                    processTextMessage(text)
                }
            case 2: // Binary
                processBinaryMessage(Data(payload))
            case 8: // Close
                Logger.info("Client sent Close frame")
                isConnected = false
            case 9: // Ping
                sendPong(data: payload)
            default:
                break // Ignore others
            }
            
            // Remove processed frame
            pendingData.removeFirst(payloadEnd)
        }
    }
    private static let connectionCounter = AtomicCounter()
    
    init(socket: SOCKET, messageHandler: WebSocketMessageHandler, path: String) {
        self.socket = socket
        self.messageHandler = messageHandler
        self.path = path
    }
    
    func start() {
        Logger.info("DEBUG: WebSocketConnection starting")
        defer {
            WinSDK.closesocket(socket)
            Logger.info("Client connection closed")
        }
        
        // 1. Handshake
        if !performHandshake() {
            Logger.error("Handshake failed")
            return
        }
        
        isConnected = true
        Logger.info("WebSocket Handshake successful")

        // Small delay to ensure client is ready to receive frame
        Thread.sleep(forTimeInterval: 0.1)

        // Send CONNECTED message
        sendConnectedMessage()

        // 2. Read Loop
        let bufferSize = 65536
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        Logger.info("DEBUG: Entering recv loop")
        while isConnected {
            let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
                guard let baseAddr = ptr.baseAddress else { return -1 }
                return baseAddr.withMemoryRebound(to: CChar.self, capacity: bufferSize) { charPtr in
                    return WinSDK.recv(socket, charPtr, Int32(bufferSize), 0)
                }
            }
            
            if bytesRead < 0 {
                let error = WSAGetLastError()
                // WSAETIMEDOUT = 10060, continue waiting for more data
                if error == 10060 {
                    continue
                }
                // Other errors, break
                Logger.debug("Recv error: \(error), closing connection")
                break
            } else if bytesRead == 0 {
                // Client closed connection gracefully
                Logger.debug("Client closed connection")
                break
            }
            
            // Logger.info("DEBUG: Read \(bytesRead) bytes")
            processData(data: Data(buffer.prefix(Int(bytesRead))))
        }
        Logger.info("DEBUG: WebSocketConnection recv loop exited")
    }
    
    private func performHandshake() -> Bool {
        // Simple HTTP Request Parser
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        let bytesRead = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
             guard let baseAddr = ptr.baseAddress else { return -1 }
             return baseAddr.withMemoryRebound(to: CChar.self, capacity: bufferSize) { charPtr in
                 return WinSDK.recv(socket, charPtr, Int32(bufferSize), 0)
             }
        }
        
        guard bytesRead > 0, let request = String(bytes: buffer.prefix(Int(bytesRead)), encoding: .utf8) else {
            return false
        }
        
        // Check Path
        guard request.contains("GET \(path) HTTP/1.1") else {
            return false
        }
        
        // Extract Key
        guard let keyRange = request.range(of: "Sec-WebSocket-Key: ") else {
            return false
        }
        
        let keyStart = keyRange.upperBound
        let keyEnd = request[keyStart...].range(of: "\r\n")?.lowerBound ?? request.endIndex
        let key = String(request[keyStart..<keyEnd])
        
        // Compute Accept Key
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let concatenated = key + magic
        guard let data = concatenated.data(using: .utf8) else { return false }
        
        let hash = SHA1.hash(data: data)
        let acceptKey = hash.base64EncodedString()
        
        // Send Response
        let response = "HTTP/1.1 101 Switching Protocols\r\n" +
                       "Upgrade: websocket\r\n" +
                       "Connection: Upgrade\r\n" +
                       "Sec-WebSocket-Accept: \(acceptKey)\r\n" +
                       "\r\n"
        
        guard let responseData = response.data(using: .utf8) else { return false }
        
        let sent = responseData.withUnsafeBytes { ptr -> Int32 in
            guard let baseAddr = ptr.baseAddress else { return -1 }
            return baseAddr.withMemoryRebound(to: CChar.self, capacity: responseData.count) { charPtr in
                return WinSDK.send(socket, charPtr, Int32(responseData.count), 0)
            }
        }
        
        return sent == responseData.count
    }

    private func sendConnectedMessage() {
        let connectionId = "conn-\(WebSocketConnection.connectionCounter.incrementAndGet())"
        let connectedMsg = AudioStreamCommon.WebSocketMessage.connected(
            streamId: connectionId,
            message: "Connection established"
        )
        sendJSON(connectedMsg)
        Logger.info("Sent CONNECTED message to client: \(connectionId)")
    }


    
    private func processTextMessage(_ text: String) {
        Logger.info("Processing text message: \(text.prefix(100))...")
        messageHandler.handleTextMessage(
            message: text,
            sendResponse: { [weak self] msg in
                self?.sendJSON(msg)
            },
            sendBinary: { [weak self] data in
                self?.sendBinary(data)
            }
        )
    }
    
    private func processBinaryMessage(_ data: Data) {
        // Logger.info("Received binary data: \(data.count) bytes")
        if let streamId = self.activeStreamId {
            Logger.debug("Handling binary message for \(streamId)")
            messageHandler.handleBinaryMessage(streamId: streamId, data: data)
            Logger.debug("Handled binary message")
        } else {
             Logger.warn("Received binary data but no active stream")
        }
    }
    
    private func sendJSON<T: Encodable>(_ data: T) {
        if let msg = data as? WebSocketMessage {
            if msg.type == AudioStreamCommon.MessageType.STARTED.rawValue {
                self.activeStreamId = msg.streamId
            } else if msg.type == AudioStreamCommon.MessageType.STOPPED.rawValue {
                self.activeStreamId = nil
            }
        }
        
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        sendFrame(opcode: 1, data: jsonData)
    }
    
    private func sendBinary(_ data: Data) {
        sendFrame(opcode: 2, data: data)
    }
    
    private func sendPong(data: [UInt8]) {
        sendFrame(opcode: 10, data: Data(data))
    }
    
    private func sendFrame(opcode: UInt8, data: Data) {
        var header = [UInt8]()
        
        // Fin + Opcode
        header.append(0x80 | (opcode & 0x0F))
        
        // Mask (Server does NOT mask) + Length
        let length = data.count
        if length <= 125 {
            header.append(UInt8(length))
        } else if length <= 65535 {
            header.append(126)
            header.append(UInt8((length >> 8) & 0xFF))
            header.append(UInt8(length & 0xFF))
        } else {
            header.append(127)
            // 64-bit length
            header.append(UInt8((length >> 56) & 0xFF))
            header.append(UInt8((length >> 48) & 0xFF))
            header.append(UInt8((length >> 40) & 0xFF))
            header.append(UInt8((length >> 32) & 0xFF))
            header.append(UInt8((length >> 24) & 0xFF))
            header.append(UInt8((length >> 16) & 0xFF))
            header.append(UInt8((length >> 8) & 0xFF))
            header.append(UInt8(length & 0xFF))
        }
        
        // Send Header
        let _ = header.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                let charPtr = base.assumingMemoryBound(to: CChar.self)
                let res = WinSDK.send(self.socket, charPtr, Int32(header.count), 0)
                if res == -1 {
                    Logger.error("Failed to send frame header: \(WSAGetLastError())")
                }
            }
        }
        
        // Send Payload
        let _ = data.withUnsafeBytes { ptr in
             if let base = ptr.baseAddress {
                let charPtr = base.assumingMemoryBound(to: CChar.self)
                let res = WinSDK.send(self.socket, charPtr, Int32(data.count), 0)
                if res == -1 {
                    Logger.error("Failed to send frame payload: \(WSAGetLastError())")
                }
            }
        }
    }
}

#else

// NON-WINDOWS Stub Implementation
class AudioWebSocketServer {
    init(port: Int = 8080, path: String = "/audio", streamManager: StreamManager, memoryPool: MemoryPoolManager) {
        Logger.warn("AudioWebSocketServer is not implemented for non-Windows platforms in this version.")
    }
    
    func start() {
        Logger.error("Cannot start AudioWebSocketServer: WinSDK is required.")
        fatalError("AudioWebSocketServer not supported on this platform")
    }
    
    func stop() {}
}

#endif
