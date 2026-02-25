/// Command type categories.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CommandType {
    Stream,
    Data,
    Query,
}

/// Stream lifecycle commands (client→server).
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum StreamCommand {
    Create,
    Complete,
    Close,
}

/// Data commands (client→server).
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum DataCommand {
    Read,
}

/// Query commands (client→server).
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum QueryCommand {
    GetStatus,
    ListStreams,
}

/// Parsed command routing info.
pub struct CommandInfo {
    pub cmd_type: CommandType,
    pub stream_cmd: Option<StreamCommand>,
    pub data_cmd: Option<DataCommand>,
    pub query_cmd: Option<QueryCommand>,
}
