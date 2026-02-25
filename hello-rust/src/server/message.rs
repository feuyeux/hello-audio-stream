use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};

use super::protocol::{CommandInfo, CommandType, DataCommand, QueryCommand, StreamCommand};

/// Unified message DTO for both client→server and server→client.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Message {
    #[serde(rename = "command")]
    pub command: String,

    #[serde(rename = "streamId", skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,

    #[serde(rename = "offset", skip_serializing_if = "Option::is_none")]
    pub offset: Option<u64>,

    #[serde(rename = "length", skip_serializing_if = "Option::is_none")]
    pub length: Option<usize>,

    #[serde(rename = "message", skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,

    #[serde(rename = "status", skip_serializing_if = "Option::is_none")]
    pub status: Option<String>,

    #[serde(rename = "size", skip_serializing_if = "Option::is_none")]
    pub size: Option<u64>,

    #[serde(rename = "streams", skip_serializing_if = "Option::is_none")]
    pub streams: Option<String>,
}

// ── Factory helpers (server→client responses) ────────────────────────────────

pub fn connected(conn_id: &str) -> Message {
    Message {
        command: "CONNECTED".to_string(),
        stream_id: Some(conn_id.to_string()),
        ..Default::default()
    }
}

pub fn created(stream_id: &str) -> Message {
    Message {
        command: "CREATED".to_string(),
        stream_id: Some(stream_id.to_string()),
        ..Default::default()
    }
}

pub fn completed(stream_id: &str) -> Message {
    Message {
        command: "COMPLETED".to_string(),
        stream_id: Some(stream_id.to_string()),
        ..Default::default()
    }
}

pub fn closed(stream_id: &str) -> Message {
    Message {
        command: "CLOSED".to_string(),
        stream_id: Some(stream_id.to_string()),
        ..Default::default()
    }
}

pub fn status(stream_id: &str, st: &str, sz: u64) -> Message {
    Message {
        command: "STATUS".to_string(),
        stream_id: Some(stream_id.to_string()),
        status: Some(st.to_string()),
        size: Some(sz),
        ..Default::default()
    }
}

pub fn stream_list(ids: &str) -> Message {
    Message {
        command: "STREAM_LIST".to_string(),
        streams: Some(ids.to_string()),
        ..Default::default()
    }
}

pub fn error(msg: &str) -> Message {
    Message {
        command: "ERROR".to_string(),
        message: Some(msg.to_string()),
        ..Default::default()
    }
}

// ── Command parsing ───────────────────────────────────────────────────────────

/// Parse a text frame JSON into a CommandInfo for routing.
pub fn parse_command(json: &str) -> Result<(Message, CommandInfo)> {
    let msg: Message = serde_json::from_str(json).map_err(|e| anyhow!("Invalid JSON: {}", e))?;

    let info = match msg.command.as_str() {
        "CREATE" => CommandInfo {
            cmd_type: CommandType::Stream,
            stream_cmd: Some(StreamCommand::Create),
            data_cmd: None,
            query_cmd: None,
        },
        "COMPLETE" => CommandInfo {
            cmd_type: CommandType::Stream,
            stream_cmd: Some(StreamCommand::Complete),
            data_cmd: None,
            query_cmd: None,
        },
        "CLOSE" => CommandInfo {
            cmd_type: CommandType::Stream,
            stream_cmd: Some(StreamCommand::Close),
            data_cmd: None,
            query_cmd: None,
        },
        "READ" => CommandInfo {
            cmd_type: CommandType::Data,
            stream_cmd: None,
            data_cmd: Some(DataCommand::Read),
            query_cmd: None,
        },
        "GET_STATUS" => CommandInfo {
            cmd_type: CommandType::Query,
            stream_cmd: None,
            data_cmd: None,
            query_cmd: Some(QueryCommand::GetStatus),
        },
        "LIST_STREAMS" => CommandInfo {
            cmd_type: CommandType::Query,
            stream_cmd: None,
            data_cmd: None,
            query_cmd: Some(QueryCommand::ListStreams),
        },
        other => return Err(anyhow!("Unknown command: {}", other)),
    };

    Ok((msg, info))
}
