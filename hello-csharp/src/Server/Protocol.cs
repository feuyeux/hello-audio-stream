namespace AudioStreamServer;

/// <summary>Command type classification.</summary>
public enum CommandType { Stream, Data, Query }

/// <summary>Stream lifecycle commands.</summary>
public enum StreamCommand { Create, Complete, Close }

/// <summary>Data transfer commands.</summary>
public enum DataCommand { Read }

/// <summary>Query commands.</summary>
public enum QueryCommand { GetStatus, ListStreams }

/// <summary>Parsed command information.</summary>
public record CommandInfo(CommandType CmdType, StreamCommand? StreamCmd, DataCommand? DataCmd, QueryCommand? QueryCmd)
{
    private static readonly Dictionary<string, CommandInfo> Map = new()
    {
        ["CREATE"]       = new(CommandType.Stream, StreamCommand.Create,   null, null),
        ["COMPLETE"]     = new(CommandType.Stream, StreamCommand.Complete, null, null),
        ["CLOSE"]        = new(CommandType.Stream, StreamCommand.Close,    null, null),
        ["READ"]         = new(CommandType.Data,   null, DataCommand.Read, null),
        ["GET_STATUS"]   = new(CommandType.Query,  null, null, QueryCommand.GetStatus),
        ["LIST_STREAMS"] = new(CommandType.Query,  null, null, QueryCommand.ListStreams),
    };

    public static CommandInfo Lookup(string command) =>
        Map.TryGetValue(command, out var info)
            ? info
            : throw new ArgumentException($"Unknown command: {command}");
}
