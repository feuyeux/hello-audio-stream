"""Per-connection WebSocket handler."""

from __future__ import annotations

import json
import logging

from websockets.asyncio.server import ServerConnection

from .stream_manager import StreamManager
from .protocol import CommandType, StreamCommand, DataCommand, QueryCommand
from . import message as msg

logger = logging.getLogger(__name__)


class Handler:
    """Per-connection handler.  Owns connection identity and active stream ID."""

    def __init__(self, mgr: StreamManager, conn_id: str, ws: ServerConnection) -> None:
        self._mgr = mgr
        self._conn_id = conn_id
        self._stream_id: str | None = None
        self._ws = ws

    # ── lifecycle ────────────────────────────────────────────────────────

    async def run(self) -> None:
        """Main message loop – call once per connection."""
        await self._send(msg.connected(self._conn_id))
        try:
            async for data in self._ws:
                if isinstance(data, bytes):
                    await self._handle_binary(data)
                else:
                    await self._handle_text(data)
        finally:
            self._on_close()

    def _on_close(self) -> None:
        if self._stream_id:
            self._mgr.mark_error(self._stream_id)
        logger.info("[%s] disconnected", self._conn_id)

    # ── dispatch ─────────────────────────────────────────────────────────

    async def _handle_text(self, text: str) -> None:
        try:
            m, info = msg.parse_command(text)
            if info.cmd_type == CommandType.STREAM:
                await self._handle_stream_cmd(info.stream_cmd, m)
            elif info.cmd_type == CommandType.DATA:
                await self._handle_data_cmd(m)
            else:
                await self._handle_query_cmd(info.query_cmd, m)
        except Exception as e:
            await self._send_error(str(e))

    async def _handle_binary(self, data: bytes) -> None:
        if not self._stream_id:
            await self._send_error("No active upload stream")
            return
        try:
            self._mgr.write(self._stream_id, data)
        except Exception as e:
            await self._send_error(str(e))

    # ── stream commands ──────────────────────────────────────────────────

    async def _handle_stream_cmd(self, cmd: StreamCommand, m: dict) -> None:
        try:
            if cmd == StreamCommand.CREATE:
                stream_id = m.get("streamId", "")
                if not stream_id:
                    raise ValueError("CREATE requires streamId")
                self._mgr.create(stream_id)
                self._stream_id = stream_id
                await self._send(msg.created(stream_id))
            elif cmd == StreamCommand.COMPLETE:
                if not self._stream_id:
                    raise ValueError("No active stream")
                sid = self._stream_id
                self._mgr.complete(sid)
                self._stream_id = None
                await self._send(msg.completed(sid))
            elif cmd == StreamCommand.CLOSE:
                stream_id = m.get("streamId", "")
                if not stream_id:
                    raise ValueError("CLOSE requires streamId")
                self._mgr.delete(stream_id)
                await self._send(msg.closed(stream_id))
        except Exception as e:
            await self._send_error(str(e))

    # ── data commands ────────────────────────────────────────────────────

    async def _handle_data_cmd(self, m: dict) -> None:
        try:
            stream_id = m.get("streamId", "")
            if not stream_id:
                raise ValueError("READ requires streamId")
            offset = m.get("offset", 0)
            length = m.get("length", 65536)
            data = self._mgr.read(stream_id, offset, length)
            if data:
                await self._ws.send(data)
            else:
                await self._send_error("No data at requested offset")
        except Exception as e:
            await self._send_error(str(e))

    # ── query commands ───────────────────────────────────────────────────

    async def _handle_query_cmd(self, cmd: QueryCommand, m: dict) -> None:
        try:
            if cmd == QueryCommand.GET_STATUS:
                stream_id = m.get("streamId", "")
                if not stream_id:
                    raise ValueError("GET_STATUS requires streamId")
                st, size = self._mgr.status_of(stream_id)
                await self._send(msg.status(stream_id, st.value, size))
            else:
                await self._send(msg.stream_list(self._mgr.list()))
        except Exception as e:
            await self._send_error(str(e))

    # ── helpers ──────────────────────────────────────────────────────────

    async def _send(self, m: dict) -> None:
        try:
            await self._ws.send(json.dumps(m))
        except Exception:
            pass

    async def _send_error(self, message: str) -> None:
        logger.warning("[%s] error: %s", self._conn_id, message)
        await self._send(msg.error(message))
