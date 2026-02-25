"""WebSocket audio stream server."""

from __future__ import annotations

import asyncio
import itertools
import logging
import os

from websockets.asyncio.server import serve, ServerConnection

from .stream_manager import StreamManager
from .handler import Handler

logger = logging.getLogger(__name__)


async def run(
    host: str = "0.0.0.0",
    port: int = 8080,
    cache_dir: str = "audio/output",
) -> None:
    """Start the audio stream server and block until cancelled."""
    os.makedirs(cache_dir, exist_ok=True)
    mgr = StreamManager(cache_dir=cache_dir)
    conn_seq = itertools.count(1)

    cleanup_task = asyncio.create_task(_cleanup_loop(mgr))

    async def on_connect(ws: ServerConnection) -> None:
        conn_id = f"c-{next(conn_seq)}"
        logger.info("[%s] connected from %s", conn_id, ws.remote_address)
        handler = Handler(mgr, conn_id, ws)
        await handler.run()

    logger.info("Server listening on ws://%s:%d", host, port)
    async with serve(
        on_connect,
        host,
        port,
        max_size=100 * 1024 * 1024,
        ping_interval=20,
        ping_timeout=20,
    ):
        await asyncio.Future()  # run forever

    cleanup_task.cancel()


async def _cleanup_loop(mgr: StreamManager) -> None:
    """Run stream cleanup every 30 seconds."""
    while True:
        await asyncio.sleep(30)
        try:
            removed = mgr.cleanup()
            if removed:
                logger.info("Cleanup removed %d stream(s)", removed)
            stats = mgr.stats()
            logger.debug(
                "Stats: total=%d uploading=%d ready=%d error=%d",
                stats.total, stats.uploading, stats.ready, stats.error,
            )
        except Exception:
            logger.exception("Cleanup error")
