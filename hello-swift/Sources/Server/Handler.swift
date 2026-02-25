import Foundation

/// Per-connection WebSocket handler.
class Handler: @unchecked Sendable {
    private let mgr: StreamManager
    let connId: String
    private var streamId: String?
    private let sendText: (String) -> Void
    private let sendBinary: (Data) -> Void

    init(mgr: StreamManager, connId: String,
         sendText: @escaping (String) -> Void,
         sendBinary: @escaping (Data) -> Void) {
        self.mgr = mgr
        self.connId = connId
        self.sendText = sendText
        self.sendBinary = sendBinary
        send(Message.connected(connId))
    }

    /// Called when a text frame is received.
    func onText(_ text: String) {
        do {
            let (m, info) = try Message.parse(text)
            switch info.cmdType {
            case .stream: try handleStreamCmd(info.streamCmd!, m)
            case .data:   try handleDataCmd(m)
            case .query:  try handleQueryCmd(info.queryCmd!, m)
            }
        } catch {
            sendError("\(error)")
        }
    }

    /// Called when a binary frame is received.
    func onBinary(_ data: Data) {
        guard let sid = streamId else {
            sendError("No active upload stream")
            return
        }
        do { try mgr.write(sid, data) }
        catch { sendError("\(error)") }
    }

    /// Called when the connection closes.
    func onClose() {
        if let sid = streamId {
            mgr.markError(sid)
        }
        print("[\(connId)] disconnected")
    }

    /// Returns the active stream ID (needed by the connection layer to track binary context).
    var activeStreamId: String? { streamId }

    // MARK: - Stream commands

    private func handleStreamCmd(_ cmd: StreamCommand, _ m: Message) throws {
        switch cmd {
        case .CREATE:
            guard let sid = m.streamId else { throw HandlerError.missing("streamId") }
            try mgr.create(sid)
            streamId = sid
            send(Message.created(sid))

        case .COMPLETE:
            guard let sid = streamId else { throw HandlerError.noActiveStream }
            try mgr.complete(sid)
            streamId = nil
            send(Message.completed(sid))

        case .CLOSE:
            guard let sid = m.streamId else { throw HandlerError.missing("streamId") }
            try mgr.delete(sid)
            send(Message.closed(sid))
        }
    }

    // MARK: - Data commands

    private func handleDataCmd(_ m: Message) throws {
        guard let sid = m.streamId else { throw HandlerError.missing("streamId") }
        let offset = m.offset ?? 0
        let length = m.length ?? 65536
        let data = try mgr.read(sid, offset: offset, length: length)
        if data.isEmpty {
            sendError("No data at requested offset")
        } else {
            sendBinary(data)
        }
    }

    // MARK: - Query commands

    private func handleQueryCmd(_ cmd: QueryCommand, _ m: Message) throws {
        switch cmd {
        case .GET_STATUS:
            guard let sid = m.streamId else { throw HandlerError.missing("streamId") }
            let (st, sz) = try mgr.statusOf(sid)
            send(Message.status(sid, st.rawValue, sz))

        case .LIST_STREAMS:
            send(Message.streamList(mgr.list()))
        }
    }

    // MARK: - Helpers

    private func send(_ m: Message) {
        sendText(m.toJson())
    }

    private func sendError(_ msg: String) {
        print("[\(connId)] error: \(msg)")
        send(Message.error(msg))
    }
}

enum HandlerError: Error, CustomStringConvertible {
    case missing(String)
    case noActiveStream

    var description: String {
        switch self {
        case .missing(let field): return "\(field) is required"
        case .noActiveStream: return "No active stream"
        }
    }
}
