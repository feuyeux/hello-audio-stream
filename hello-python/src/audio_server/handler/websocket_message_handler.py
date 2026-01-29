"""
WebSocket message handler for processing incoming messages.
Handles message routing and business logic.
"""

import json
from websockets.asyncio.server import ServerConnection
from loguru import logger

from audio_server.memory.stream_manager import StreamManager
from audio_server.handler.websocket_message import WebSocketMessage, MessageType


class WebSocketMessageHandler:
    """
    Handler for WebSocket messages.
    Routes messages to appropriate stream operations.
    """

    def __init__(self, stream_manager: StreamManager):
        """
        Initialize message handler.

        Args:
            stream_manager: StreamManager instance for stream operations
        """
        self.stream_manager = stream_manager

    async def handle_message(self, websocket: ServerConnection, message):
        """
        Handle a message from a client.

        Args:
            websocket: WebSocket connection
            message: Message data (text or binary)
        """
        try:
            # Check if message is binary (audio data)
            if isinstance(message, bytes):
                await self.handle_binary_message(websocket, message)
            else:
                # Text message (JSON control message)
                await self.handle_text_message(websocket, message)

        except Exception as e:
            logger.error(f"Error handling message: {e}")
            await self.send_error(websocket, str(e))

    async def handle_text_message(self, websocket: ServerConnection, message: str):
        """
        Handle a text (JSON) control message.

        Args:
            websocket: WebSocket connection
            message: JSON message string
        """
        try:
            msg = WebSocketMessage.from_json(message)
            msg_type = msg.get_message_type()

            if msg_type is None:
                logger.warning(f"Unknown message type: {msg.type}")
                await self.send_error(websocket, f"Unknown message type: {msg.type}")
                return

            if msg_type == MessageType.START:
                await self.handle_start(websocket, msg)
            elif msg_type == MessageType.STOP:
                await self.handle_stop(websocket, msg)
            elif msg_type == MessageType.GET:
                await self.handle_get(websocket, msg)
            else:
                logger.warning(f"Unhandled message type: {msg_type}")
                await self.send_error(websocket, f"Unhandled message type: {msg_type}")

        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON message: {e}")
            await self.send_error(websocket, "Invalid JSON format")

    async def handle_binary_message(self, websocket: ServerConnection, data: bytes):
        """
        Handle binary audio data.

        Args:
            websocket: WebSocket connection
            data: Binary audio data
        """
        logger.debug(f"Received {len(data)} bytes of binary data")

        # Get the current stream ID for this connection
        # We need to track which stream is associated with this websocket
        if not hasattr(websocket, 'current_stream_id'):
            logger.error("Received binary data without active stream")
            await self.send_error(websocket, "No active stream for binary data")
            return

        stream_id = websocket.current_stream_id  # type: ignore[attr-defined]

        # Write data to stream
        if not self.stream_manager.write_chunk(stream_id, data):
            logger.error(
                f"Failed to write {len(data)} bytes to stream {stream_id}")
            await self.send_error(websocket, f"Failed to write data to stream: {stream_id}")

    async def handle_start(self, websocket: ServerConnection, msg: WebSocketMessage):
        """
        Handle START message (create new stream).

        Args:
            websocket: WebSocket connection
            msg: Parsed WebSocketMessage
        """
        stream_id = msg.streamId
        if not stream_id:
            await self.send_error(websocket, "Missing streamId")
            return

        # Create stream
        if self.stream_manager.create_stream(stream_id):
            # Associate this stream with the websocket connection
            # type: ignore[attr-defined]
            websocket.current_stream_id = stream_id

            response = WebSocketMessage.started(stream_id)
            await websocket.send(response.to_json())
            logger.info(f"Stream started: {stream_id}")
        else:
            await self.send_error(websocket, f"Failed to create stream: {stream_id}")

    async def handle_stop(self, websocket: ServerConnection, msg: WebSocketMessage):
        """
        Handle STOP message (finalize stream).

        Args:
            websocket: WebSocket connection
            msg: Parsed WebSocketMessage
        """
        stream_id = msg.streamId
        if not stream_id:
            await self.send_error(websocket, "Missing streamId")
            return

        # Finalize stream
        if self.stream_manager.finalize_stream(stream_id):
            response = WebSocketMessage.stopped(stream_id)
            await websocket.send(response.to_json())
            logger.info(f"Stream finalized: {stream_id}")
        else:
            await self.send_error(websocket, f"Failed to finalize stream: {stream_id}")

    async def handle_get(self, websocket: ServerConnection, msg: WebSocketMessage):
        """
        Handle GET message (read stream data).

        Args:
            websocket: WebSocket connection
            msg: Parsed WebSocketMessage containing stream_id, offset, and length
        """
        stream_id = msg.streamId
        offset = msg.offset if msg.offset is not None else 0
        length = msg.length if msg.length is not None else 65536

        if not stream_id:
            await self.send_error(websocket, "Missing streamId")
            return

        # Read data from stream
        chunk_data = self.stream_manager.read_chunk(stream_id, offset, length)

        if chunk_data:
            # Send binary data
            await websocket.send(chunk_data)
            logger.debug(
                f"Sent {len(chunk_data)} bytes for stream {stream_id} at offset {offset}")
        else:
            await self.send_error(websocket, f"Failed to read from stream: {stream_id}")

    async def send_error(self, websocket: ServerConnection, message: str):
        """
        Send an error message to the client.

        Args:
            websocket: WebSocket connection
            message: Error message
        """
        response = WebSocketMessage.error(message)
        await websocket.send(response.to_json())
        logger.error(f"Sent error to client: {message}")
