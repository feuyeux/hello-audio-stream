"""Unified message DTO and command parsing."""
import json
from typing import Any, Dict, Optional, Tuple

from .protocol import (
    CommandInfo, CommandType, DataCommand, QueryCommand, StreamCommand,
)

# Type alias
Message = Dict[str, Any]


# ── Factory helpers (server→client) ──────────────────────────────────────────

def connected(conn_id: str) -> Message:
    return {"command": "CONNECTED", "streamId": conn_id}


def created(stream_id: str) -> Message:
    return {"command": "CREATED", "streamId": stream_id}


def completed(stream_id: str) -> Message:
    return {"command": "COMPLETED", "streamId": stream_id}


def closed(stream_id: str) -> Message:
    return {"command": "CLOSED", "streamId": stream_id}


def status(stream_id: str, st: str, size: int) -> Message:
    return {"command": "STATUS", "streamId": stream_id, "status": st, "size": size}


def stream_list(streams: str) -> Message:
    return {"command": "STREAM_LIST", "streams": streams}


def error(message: str) -> Message:
    return {"command": "ERROR", "message": message}


# ── Command parsing ──────────────────────────────────────────────────────────

_COMMAND_MAP = {
    "CREATE": CommandInfo(CommandType.STREAM, stream_cmd=StreamCommand.CREATE),
    "COMPLETE": CommandInfo(CommandType.STREAM, stream_cmd=StreamCommand.COMPLETE),
    "CLOSE": CommandInfo(CommandType.STREAM, stream_cmd=StreamCommand.CLOSE),
    "READ": CommandInfo(CommandType.DATA, data_cmd=DataCommand.READ),
    "GET_STATUS": CommandInfo(CommandType.QUERY, query_cmd=QueryCommand.GET_STATUS),
    "LIST_STREAMS": CommandInfo(CommandType.QUERY, query_cmd=QueryCommand.LIST_STREAMS),
}


def parse_command(text: str) -> Tuple[Message, CommandInfo]:
    """Parse a JSON text frame into (msg, CommandInfo)."""
    try:
        msg = json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON: {e}") from e

    cmd = msg.get("command", "")
    info = _COMMAND_MAP.get(cmd)
    if info is None:
        raise ValueError(f"Unknown command: {cmd}")
    return msg, info
