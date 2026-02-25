import Foundation
#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - Atomic counter for connection IDs

final class AtomicCounter: @unchecked Sendable {
    private var value: UInt32 = 0
    private let lock = NSLock()

    func next() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

private let connCounter = AtomicCounter()

// MARK: - WebSocket server

#if os(Windows)

typealias SOCKET = UInt64
private let INVALID_SOCKET: SOCKET = 0xFFFFFFFFFFFFFFFF

class WebSocketServer: @unchecked Sendable {
    private let port: Int
    private let mgr: StreamManager
    private var listenSocket: SOCKET = INVALID_SOCKET
    private var isRunning = false

    nonisolated(unsafe) private static var wsaInitialized = false

    init(port: Int, mgr: StreamManager) {
        self.port = port
        self.mgr = mgr
        if !Self.wsaInitialized {
            var wsaData = WSAData()
            if WSAStartup(UInt16(0x0202), &wsaData) == 0 {
                Self.wsaInitialized = true
            }
        }
    }

    deinit { stop() }

    func start() {
        guard Self.wsaInitialized else { print("Winsock not initialized"); return }

        listenSocket = WinSDK.socket(Int32(AF_INET), Int32(SOCK_STREAM), Int32(IPPROTO_TCP.rawValue))
        guard listenSocket != INVALID_SOCKET else { print("socket() failed"); return }

        var addr = sockaddr_in()
        addr.sin_family = ADDRESS_FAMILY(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.S_un.S_addr = 0

        let ok = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                WinSDK.bind(listenSocket, sp, Int32(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard ok != -1 else { print("bind() failed"); WinSDK.closesocket(listenSocket); return }
        guard WinSDK.listen(listenSocket, SOMAXCONN) != -1 else { print("listen() failed"); return }

        isRunning = true
        print("WebSocket server listening on ws://0.0.0.0:\(port)")

        Task.detached { [weak self] in self?.acceptLoop() }
    }

    func stop() {
        isRunning = false
        if listenSocket != INVALID_SOCKET {
            WinSDK.closesocket(listenSocket)
            listenSocket = INVALID_SOCKET
        }
    }

    private func acceptLoop() {
        while isRunning {
            let client = WinSDK.accept(listenSocket, nil, nil)
            if client == INVALID_SOCKET { continue }
            let mgr = self.mgr
            Task.detached {
                WinConnection(socket: client, mgr: mgr).run()
            }
        }
    }
}

// MARK: - Windows connection

private class WinConnection {
    private let socket: SOCKET
    private let handler: Handler
    private var pending: [UInt8] = []

    init(socket: SOCKET, mgr: StreamManager) {
        let connId = "c-\(connCounter.next())"
        self.socket = socket
        self.handler = Handler(mgr: mgr, connId: connId,
                               sendText: { [socket] text in
                                   guard let data = text.data(using: .utf8) else { return }
                                   WinConnection.sendFrame(socket: socket, opcode: 1, data: data)
                               },
                               sendBinary: { [socket] data in
                                   WinConnection.sendFrame(socket: socket, opcode: 2, data: data)
                               })
    }

    func run() {
        defer {
            handler.onClose()
            WinSDK.closesocket(socket)
        }

        guard performHandshake() else { return }

        var buffer = [UInt8](repeating: 0, count: 65536)
        var connected = true
        while connected {
            let n = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return -1 }
                return base.withMemoryRebound(to: CChar.self, capacity: ptr.count) { cp in
                    WinSDK.recv(socket, cp, Int32(ptr.count), 0)
                }
            }
            if n <= 0 { break }
            pending.append(contentsOf: buffer.prefix(Int(n)))
            connected = processFrames()
        }
    }

    private func processFrames() -> Bool {
        while true {
            guard pending.count >= 2 else { return true }
            let byte2 = pending[1]
            let masked = (byte2 & 0x80) != 0
            var payloadLen = UInt64(byte2 & 0x7F)
            var hdrSize = 2

            if payloadLen == 126 {
                guard pending.count >= 4 else { return true }
                payloadLen = (UInt64(pending[2]) << 8) | UInt64(pending[3])
                hdrSize += 2
            } else if payloadLen == 127 {
                guard pending.count >= 10 else { return true }
                payloadLen = 0
                for i in 0..<8 { payloadLen = (payloadLen << 8) | UInt64(pending[2 + i]) }
                hdrSize += 8
            }

            if masked { guard pending.count >= hdrSize + 4 else { return true }; hdrSize += 4 }
            guard UInt64(pending.count) >= UInt64(hdrSize) + payloadLen else { return true }

            var payload = [UInt8](pending[(hdrSize - (masked ? 4 : 0) + (masked ? 4 : 0))..<(hdrSize + Int(payloadLen))])
            if masked {
                let maskStart = hdrSize - 4
                let mask = Array(pending[maskStart..<(maskStart + 4)])
                // Re-extract payload after mask key
                payload = [UInt8](pending[hdrSize..<(hdrSize + Int(payloadLen))])
                for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
            }

            let opcode = pending[0] & 0x0F
            pending.removeFirst(hdrSize + Int(payloadLen))

            switch opcode {
            case 1:
                if let text = String(bytes: payload, encoding: .utf8) { handler.onText(text) }
            case 2:
                handler.onBinary(Data(payload))
            case 8:
                return false
            case 9:
                Self.sendFrame(socket: socket, opcode: 10, data: Data(payload))
            default: break
            }
        }
    }

    private func performHandshake() -> Bool {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return base.withMemoryRebound(to: CChar.self, capacity: ptr.count) { cp in
                WinSDK.recv(socket, cp, Int32(ptr.count), 0)
            }
        }
        guard n > 0, let req = String(bytes: buf.prefix(Int(n)), encoding: .utf8) else { return false }
        guard req.contains("GET ") else { return false }
        guard let keyRange = req.range(of: "Sec-WebSocket-Key: ") else { return false }
        let keyStart = keyRange.upperBound
        let keyEnd = req[keyStart...].range(of: "\r\n")?.lowerBound ?? req.endIndex
        let key = String(req[keyStart..<keyEnd])

        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        guard let data = (key + magic).data(using: .utf8) else { return false }
        let accept = SHA1.hash(data: data).base64EncodedString()

        let resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
        guard let respData = resp.data(using: .utf8) else { return false }
        let sent = respData.withUnsafeBytes { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return -1 }
            return base.withMemoryRebound(to: CChar.self, capacity: respData.count) { cp in
                WinSDK.send(socket, cp, Int32(respData.count), 0)
            }
        }
        return sent == respData.count
    }

    static func sendFrame(socket: SOCKET, opcode: UInt8, data: Data) {
        var header = [UInt8]()
        header.append(0x80 | (opcode & 0x0F))
        let len = data.count
        if len <= 125 {
            header.append(UInt8(len))
        } else if len <= 65535 {
            header.append(126)
            header.append(UInt8((len >> 8) & 0xFF))
            header.append(UInt8(len & 0xFF))
        } else {
            header.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                header.append(UInt8((len >> shift) & 0xFF))
            }
        }
        _ = header.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                base.withMemoryRebound(to: CChar.self, capacity: header.count) { cp in
                    WinSDK.send(socket, cp, Int32(header.count), 0)
                }
            }
        }
        _ = data.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                base.withMemoryRebound(to: CChar.self, capacity: data.count) { cp in
                    WinSDK.send(socket, cp, Int32(data.count), 0)
                }
            }
        }
    }
}

#else

// MARK: - POSIX server

class WebSocketServer: @unchecked Sendable {
    private let port: Int
    private let mgr: StreamManager
    private var listenSocket: Int32 = -1
    private var isRunning = false

    init(port: Int, mgr: StreamManager) {
        self.port = port
        self.mgr = mgr
    }

    deinit { stop() }

    func start() {
        #if canImport(Glibc)
        let sockType = Int32(SOCK_STREAM.rawValue)
        #else
        let sockType = SOCK_STREAM
        #endif

        listenSocket = socket(AF_INET, sockType, 0)
        guard listenSocket >= 0 else { print("socket() failed"); return }

        var opt: Int32 = 1
        withUnsafePointer(to: &opt) { p in
            p.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<Int32>.size) { cp in
                _ = setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, cp, socklen_t(MemoryLayout<Int32>.size))
            }
        }

        var addr = sockaddr_in()
        #if canImport(Darwin)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr = in_addr(s_addr: 0)

        let bindOk = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                bind(listenSocket, sp, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindOk == 0 else { print("bind() failed"); closeSocket(listenSocket); return }
        guard listen(listenSocket, SOMAXCONN) == 0 else { print("listen() failed"); return }

        isRunning = true
        print("WebSocket server listening on ws://0.0.0.0:\(port)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        isRunning = false
        if listenSocket >= 0 { closeSocket(listenSocket); listenSocket = -1 }
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr()
            var clientLen = socklen_t(MemoryLayout<sockaddr>.size)
            let client = withUnsafeMutablePointer(to: &clientAddr) { p in
                accept(listenSocket, p, &clientLen)
            }
            if client < 0 { continue }
            let mgr = self.mgr
            DispatchQueue.global(qos: .utility).async {
                PosixConnection(socket: client, mgr: mgr).run()
            }
        }
    }

    private func closeSocket(_ fd: Int32) {
        #if canImport(Darwin)
        _ = Darwin.shutdown(fd, SHUT_RDWR); _ = Darwin.close(fd)
        #else
        _ = Glibc.shutdown(fd, Int32(SHUT_RDWR)); _ = Glibc.close(fd)
        #endif
    }
}

// MARK: - POSIX connection

private class PosixConnection {
    private let socket: Int32
    private let handler: Handler
    private var pending: [UInt8] = []

    init(socket: Int32, mgr: StreamManager) {
        let connId = "c-\(connCounter.next())"
        self.socket = socket
        self.handler = Handler(mgr: mgr, connId: connId,
                               sendText: { [socket] text in
                                   guard let data = text.data(using: .utf8) else { return }
                                   PosixConnection.sendFrame(socket: socket, opcode: 1, data: data)
                               },
                               sendBinary: { [socket] data in
                                   PosixConnection.sendFrame(socket: socket, opcode: 2, data: data)
                               })
    }

    func run() {
        defer {
            handler.onClose()
            closeSocket(socket)
        }

        guard performHandshake() else { return }

        var buffer = [UInt8](repeating: 0, count: 65536)
        var connected = true
        while connected {
            let n = recvBytes(into: &buffer)
            if n <= 0 {
                #if canImport(Darwin)
                if n < 0 && errno == EINTR { continue }
                #else
                if n < 0 && errno == EINTR { continue }
                #endif
                break
            }
            pending.append(contentsOf: buffer.prefix(n))
            connected = processFrames()
        }
    }

    private func recvBytes(into buffer: inout [UInt8]) -> Int {
        buffer.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return -1 }
            #if canImport(Darwin)
            return Int(Darwin.recv(socket, base, ptr.count, 0))
            #else
            return Int(Glibc.recv(socket, base, ptr.count, 0))
            #endif
        }
    }

    private func processFrames() -> Bool {
        while true {
            guard pending.count >= 2 else { return true }
            let byte2 = pending[1]
            let masked = (byte2 & 0x80) != 0
            var payloadLen = UInt64(byte2 & 0x7F)
            var hdrSize = 2

            if payloadLen == 126 {
                guard pending.count >= 4 else { return true }
                payloadLen = (UInt64(pending[2]) << 8) | UInt64(pending[3])
                hdrSize += 2
            } else if payloadLen == 127 {
                guard pending.count >= 10 else { return true }
                payloadLen = 0
                for i in 0..<8 { payloadLen = (payloadLen << 8) | UInt64(pending[2 + i]) }
                hdrSize += 8
            }

            if masked { guard pending.count >= hdrSize + 4 else { return true }; hdrSize += 4 }
            guard UInt64(pending.count) >= UInt64(hdrSize) + payloadLen else { return true }

            var payload = [UInt8](pending[hdrSize..<(hdrSize + Int(payloadLen))])
            if masked {
                let maskStart = hdrSize - 4
                let mask = Array(pending[maskStart..<(maskStart + 4)])
                for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
            }

            let opcode = pending[0] & 0x0F
            pending.removeFirst(hdrSize + Int(payloadLen))

            switch opcode {
            case 1:
                if let text = String(bytes: payload, encoding: .utf8) { handler.onText(text) }
            case 2:
                handler.onBinary(Data(payload))
            case 8:
                return false
            case 9:
                Self.sendFrame(socket: socket, opcode: 10, data: Data(payload))
            default: break
            }
        }
    }

    private func performHandshake() -> Bool {
        var buf = [UInt8](repeating: 0, count: 8192)
        let n = recvBytes(into: &buf)
        guard n > 0, let req = String(bytes: buf.prefix(n), encoding: .utf8) else { return false }

        let lines = req.components(separatedBy: "\r\n")
        guard lines.first?.contains("GET ") == true else { return false }

        guard let keyLine = lines.first(where: { $0.lowercased().hasPrefix("sec-websocket-key:") }) else {
            return false
        }
        let key = keyLine.split(separator: ":", maxSplits: 1).dropFirst().first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else { return false }

        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        guard let data = (key + magic).data(using: .utf8) else { return false }
        let accept = SHA1.hash(data: data).base64EncodedString()

        let resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
        return sendAll(Data(resp.utf8))
    }

    static func sendFrame(socket: Int32, opcode: UInt8, data: Data) {
        var header = [UInt8]()
        header.append(0x80 | (opcode & 0x0F))
        let len = data.count
        if len <= 125 {
            header.append(UInt8(len))
        } else if len <= 65535 {
            header.append(126)
            header.append(UInt8((len >> 8) & 0xFF))
            header.append(UInt8(len & 0xFF))
        } else {
            header.append(127)
            for shift in stride(from: 56, through: 0, by: -8) {
                header.append(UInt8((len >> shift) & 0xFF))
            }
        }
        _ = sendAllStatic(socket: socket, Data(header))
        _ = sendAllStatic(socket: socket, data)
    }

    private func sendAll(_ data: Data) -> Bool {
        Self.sendAllStatic(socket: socket, data)
    }

    private static func sendAllStatic(socket: Int32, _ data: Data) -> Bool {
        var sent = 0
        return data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return false }
            while sent < ptr.count {
                let chunk = base.advanced(by: sent)
                let remaining = ptr.count - sent
                #if canImport(Darwin)
                let n = Darwin.send(socket, chunk, remaining, 0)
                #else
                let n = Glibc.send(socket, chunk, remaining, 0)
                #endif
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    private func closeSocket(_ fd: Int32) {
        #if canImport(Darwin)
        _ = Darwin.shutdown(fd, SHUT_RDWR); _ = Darwin.close(fd)
        #else
        _ = Glibc.shutdown(fd, Int32(SHUT_RDWR)); _ = Glibc.close(fd)
        #endif
    }
}

#endif
