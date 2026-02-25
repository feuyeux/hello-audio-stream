import Foundation

/// Command category.
enum CommandType {
    case stream, data, query
}

/// Stream lifecycle commands (client → server).
enum StreamCommand: String, CaseIterable {
    case CREATE, COMPLETE, CLOSE
}

/// Data transfer commands (client → server).
enum DataCommand: String, CaseIterable {
    case READ
}

/// Query commands (client → server).
enum QueryCommand: String, CaseIterable {
    case GET_STATUS, LIST_STREAMS
}

/// Parsed command descriptor.
struct CommandInfo {
    let cmdType: CommandType
    let streamCmd: StreamCommand?
    let dataCmd: DataCommand?
    let queryCmd: QueryCommand?
}

/// Lookup table: command string → CommandInfo
let commandLookup: [String: CommandInfo] = {
    var map: [String: CommandInfo] = [:]
    for c in StreamCommand.allCases {
        map[c.rawValue] = CommandInfo(cmdType: .stream, streamCmd: c, dataCmd: nil, queryCmd: nil)
    }
    for c in DataCommand.allCases {
        map[c.rawValue] = CommandInfo(cmdType: .data, streamCmd: nil, dataCmd: c, queryCmd: nil)
    }
    for c in QueryCommand.allCases {
        map[c.rawValue] = CommandInfo(cmdType: .query, streamCmd: nil, dataCmd: nil, queryCmd: c)
    }
    return map
}()
