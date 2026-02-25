"""Protocol command types and routing."""
from dataclasses import dataclass
from enum import Enum, auto
from typing import Optional


class CommandType(Enum):
    STREAM = auto()
    DATA = auto()
    QUERY = auto()


class StreamCommand(Enum):
    CREATE = auto()
    COMPLETE = auto()
    CLOSE = auto()


class DataCommand(Enum):
    READ = auto()


class QueryCommand(Enum):
    GET_STATUS = auto()
    LIST_STREAMS = auto()


@dataclass
class CommandInfo:
    cmd_type: CommandType
    stream_cmd: Optional[StreamCommand] = None
    data_cmd: Optional[DataCommand] = None
    query_cmd: Optional[QueryCommand] = None
