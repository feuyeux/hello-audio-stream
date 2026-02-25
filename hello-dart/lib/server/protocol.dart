enum CommandType { stream, data, query }

enum StreamCommand {
  create('CREATE'),
  complete('COMPLETE'),
  close('CLOSE');

  final String value;
  const StreamCommand(this.value);
}

enum DataCommand {
  read('READ');

  final String value;
  const DataCommand(this.value);
}

enum QueryCommand {
  getStatus('GET_STATUS'),
  listStreams('LIST_STREAMS');

  final String value;
  const QueryCommand(this.value);
}

class CommandInfo {
  final CommandType type;
  final String command;
  const CommandInfo(this.type, this.command);
}

class Protocol {
  static final Map<String, CommandInfo> _map = _buildMap();

  static Map<String, CommandInfo> _buildMap() {
    final m = <String, CommandInfo>{};
    for (final c in StreamCommand.values) {
      m[c.value] = CommandInfo(CommandType.stream, c.value);
    }
    for (final c in DataCommand.values) {
      m[c.value] = CommandInfo(CommandType.data, c.value);
    }
    for (final c in QueryCommand.values) {
      m[c.value] = CommandInfo(CommandType.query, c.value);
    }
    return m;
  }

  static CommandInfo? lookup(String command) => _map[command];
}
