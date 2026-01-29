"""
WebSocket message data classes for JSON serialization/deserialization.
"""

from dataclasses import dataclass, asdict
from typing import Optional
import json
from enum import Enum


class MessageType(str, Enum):
    """
    WebSocket message types enum.
    All type values are uppercase as per protocol specification.
    """
    START = "START"
    STARTED = "STARTED"
    STOP = "STOP"
    STOPPED = "STOPPED"
    GET = "GET"
    ERROR = "ERROR"
    CONNECTED = "CONNECTED"

    @classmethod
    def from_string(cls, value: Optional[str]) -> Optional['MessageType']:
        """
        Parse string to MessageType enum.
        Case-insensitive comparison for backward compatibility.
        """
        if value is None:
            return None
        try:
            return cls[value.upper()]
        except KeyError:
            return None


@dataclass
class WebSocketMessage:
    """
    WebSocket control message for client-server communication.
    Used for all control messages including START, STOP, GET, and responses.
    """
    type: str
    streamId: Optional[str] = None
    offset: Optional[int] = None
    length: Optional[int] = None
    message: Optional[str] = None

    def to_json(self) -> str:
        """Convert to JSON string, excluding None values."""
        data = {k: v for k, v in asdict(self).items() if v is not None}
        return json.dumps(data)

    def to_dict(self) -> dict:
        """Convert to dictionary, excluding None values."""
        return {k: v for k, v in asdict(self).items() if v is not None}

    @classmethod
    def from_json(cls, json_str: str) -> 'WebSocketMessage':
        """Parse from JSON string."""
        data = json.loads(json_str)
        return cls.from_dict(data)

    @classmethod
    def from_dict(cls, data: dict) -> 'WebSocketMessage':
        """Parse from dictionary."""
        return cls(
            type=data.get("type", ""),
            streamId=data.get("streamId"),
            offset=data.get("offset"),
            length=data.get("length"),
            message=data.get("message")
        )

    def get_message_type(self) -> Optional[MessageType]:
        """
        Get the message type as MessageType enum.
        """
        return MessageType.from_string(self.type)

    @classmethod
    def started(cls, stream_id: str, message: str = "Stream started successfully") -> 'WebSocketMessage':
        """Create a STARTED response message."""
        return cls(type="STARTED", streamId=stream_id, message=message)

    @classmethod
    def stopped(cls, stream_id: str, message: str = "Stream finalized successfully") -> 'WebSocketMessage':
        """Create a STOPPED response message."""
        return cls(type="STOPPED", streamId=stream_id, message=message)

    @classmethod
    def error(cls, message: str) -> 'WebSocketMessage':
        """Create an ERROR response message."""
        return cls(type="ERROR", message=message)
