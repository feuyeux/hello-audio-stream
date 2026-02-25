"""Audio stream client — single-file implementation."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import time
from pathlib import Path

import websockets

logger = logging.getLogger(__name__)

CHUNK_SIZE = 64 * 1024  # 64 KB


class Client:
    """Connects to the audio stream server, uploads a file, downloads it back,
    and verifies integrity."""

    def __init__(self, server_uri: str) -> None:
        self._uri = server_uri
        self._ws: websockets.WebSocketClientProtocol | None = None
        self._conn_id: str | None = None

    # ── public API ───────────────────────────────────────────────────────

    async def connect(self) -> None:
        self._ws = await websockets.connect(
            self._uri,
            max_size=100 * 1024 * 1024,
            ping_interval=20,
            ping_timeout=20,
        )
        resp = await self._recv_json()
        if resp.get("command") != "CONNECTED":
            raise RuntimeError(f"Expected CONNECTED, got {resp}")
        self._conn_id = resp.get("streamId", "")
        logger.info("Connected as %s", self._conn_id)

    async def upload(self, file_path: str, stream_id: str) -> None:
        """Upload a file as the given stream ID."""
        assert self._ws is not None
        # CREATE
        await self._send_json({"command": "CREATE", "streamId": stream_id})
        resp = await self._recv_json()
        if resp.get("command") != "CREATED":
            raise RuntimeError(f"Expected CREATED, got {resp}")
        logger.info("Stream created: %s", stream_id)

        # send binary data
        file_size = os.path.getsize(file_path)
        sent = 0
        t0 = time.monotonic()
        with open(file_path, "rb") as f:
            while True:
                chunk = f.read(CHUNK_SIZE)
                if not chunk:
                    break
                await self._ws.send(chunk)
                sent += len(chunk)
        elapsed = time.monotonic() - t0
        mbps = (file_size * 8 / 1_000_000) / elapsed if elapsed > 0 else 0
        logger.info("Uploaded %d bytes in %.1f ms (%.1f Mbps)", sent, elapsed * 1000, mbps)

        # COMPLETE
        await self._send_json({"command": "COMPLETE"})
        resp = await self._recv_json()
        if resp.get("command") != "COMPLETED":
            raise RuntimeError(f"Expected COMPLETED, got {resp}")
        logger.info("Stream completed: %s", stream_id)

    async def download(self, stream_id: str, output_path: str, expected_size: int) -> None:
        """Download stream data to a file."""
        assert self._ws is not None
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

        received = 0
        t0 = time.monotonic()
        with open(output_path, "wb") as f:
            while received < expected_size:
                length = min(CHUNK_SIZE, expected_size - received)
                await self._send_json({
                    "command": "READ",
                    "streamId": stream_id,
                    "offset": received,
                    "length": length,
                })
                data = await self._ws.recv()
                if isinstance(data, str):
                    resp = json.loads(data)
                    if resp.get("command") == "ERROR":
                        raise RuntimeError(f"Server error: {resp.get('message')}")
                    raise RuntimeError(f"Expected binary, got {resp}")
                f.write(data)
                received += len(data)
        elapsed = time.monotonic() - t0
        mbps = (received * 8 / 1_000_000) / elapsed if elapsed > 0 else 0
        logger.info("Downloaded %d bytes in %.1f ms (%.1f Mbps)", received, elapsed * 1000, mbps)

    async def close(self) -> None:
        if self._ws:
            await self._ws.close()
            self._ws = None

    # ── verification ─────────────────────────────────────────────────────

    @staticmethod
    def verify(original: str, downloaded: str) -> bool:
        """Compare two files by size and MD5."""
        if os.path.getsize(original) != os.path.getsize(downloaded):
            logger.error(
                "Size mismatch: %d vs %d",
                os.path.getsize(original),
                os.path.getsize(downloaded),
            )
            return False
        h1 = _md5(original)
        h2 = _md5(downloaded)
        if h1 != h2:
            logger.error("Checksum mismatch: %s vs %s", h1, h2)
            return False
        logger.info("Verification passed (MD5: %s)", h1)
        return True

    # ── internal helpers ─────────────────────────────────────────────────

    async def _send_json(self, m: dict) -> None:
        assert self._ws is not None
        await self._ws.send(json.dumps(m))

    async def _recv_json(self) -> dict:
        assert self._ws is not None
        raw = await self._ws.recv()
        if isinstance(raw, bytes):
            raw = raw.decode()
        return json.loads(raw)


def _md5(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(CHUNK_SIZE), b""):
            h.update(chunk)
    return h.hexdigest()


# ── run (entry point) ────────────────────────────────────────────────────

async def run(
    server: str,
    input_file: str,
    output_file: str,
    stream_id: str | None = None,
) -> None:
    """Full workflow: connect → upload → download → verify → close."""
    if not stream_id:
        stream_id = f"stream-{int(time.time() * 1000)}"

    file_size = os.path.getsize(input_file)
    logger.info("Input: %s (%d bytes)", input_file, file_size)

    client = Client(server)
    try:
        await client.connect()
        await client.upload(input_file, stream_id)
        await asyncio.sleep(1)
        await client.download(stream_id, output_file, file_size)

        if Client.verify(input_file, output_file):
            logger.info("Workflow complete — files match")
        else:
            raise RuntimeError("Verification failed")
    finally:
        await client.close()
