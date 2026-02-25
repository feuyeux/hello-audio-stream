import Foundation

/// JSON message for WebSocket communication.
struct Message: Codable {
    let command: String
    var streamId: String?
    var offset: Int64?
    var length: Int?
    var message: String?
    var status: String?
    var size: Int64?
    var streams: String?

    // MARK: - Factory methods (server → client)

    static func connected(_ connId: String) -> Message {
        Message(command: "CONNECTED", streamId: connId)
    }

    static func created(_ streamId: String) -> Message {
        Message(command: "CREATED", streamId: streamId)
    }

    static func completed(_ streamId: String) -> Message {
        Message(command: "COMPLETED", streamId: streamId)
    }

    static func closed(_ streamId: String) -> Message {
        Message(command: "CLOSED", streamId: streamId)
    }

    static func error(_ msg: String) -> Message {
        Message(command: "ERROR", message: msg)
    }

    static func status(_ streamId: String, _ st: String, _ sz: Int64) -> Message {
        Message(command: "STATUS", streamId: streamId, status: st, size: sz)
    }

    static func streamList(_ ids: [String]) -> Message {
        Message(command: "STREAM_LIST", streams: ids.joined(separator: ","))
    }

    // MARK: - Parse

    /// Parse JSON text into Message + CommandInfo.
    static func parse(_ text: String) throws -> (Message, CommandInfo) {
        guard let data = text.data(using: .utf8) else {
            throw MessageError.invalidJson
        }
        let m = try JSONDecoder().decode(Message.self, from: data)
        guard let info = commandLookup[m.command] else {
            throw MessageError.unknownCommand(m.command)
        }
        return (m, info)
    }

    /// Serialize to JSON string.
    func toJson() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

enum MessageError: Error, CustomStringConvertible {
    case invalidJson
    case unknownCommand(String)

    var description: String {
        switch self {
        case .invalidJson: return "Invalid JSON"
        case .unknownCommand(let cmd): return "Unknown command: \(cmd)"
        }
    }
}
