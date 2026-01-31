"""
WebSocket server for audio streaming.
Handles client connections and message routing.
Matches C++ WebSocketServer and Java AudioWebSocketServer functionality.
"""

import asyncio
from typing import Set
import websockets
from websockets.asyncio.server import serve, ServerConnection
from loguru import logger

from ..memory.stream_manager import StreamManager
from ..memory.memory_pool_manager import MemoryPoolManager
from ..handler.websocket_message_handler import WebSocketMessageHandler


class AudioWebSocketServer:
    """
    WebSocket server for handling audio stream uploads and downloads.
    Manages client connections and routes messages to handler.
    """

    def __init__(self, host: str = "0.0.0.0", port: int = 8080, path: str = "/audio"):
        """
        Initialize WebSocket server.

        Args:
            host: Host address to bind to
            port: Port number to listen on
            path: WebSocket endpoint path
        """
        self.host = host
        self.port = port
        self.path = path
        self.clients: Set[ServerConnection] = set()
        self.stream_manager = StreamManager.get_instance()
        self.memory_pool = MemoryPoolManager.get_instance()
        self.message_handler = WebSocketMessageHandler(self.stream_manager)
        self.server = None

        logger.info(f"AudioWebSocketServer initialized on {host}:{port}{path}")

    async def start(self):
        """Start the WebSocket server"""
        self.server = await serve(
            self.handle_client,
            self.host,
            self.port,
            max_size=100 * 1024 * 1024,  # 100MB max message size
            ping_interval=20,
            ping_timeout=20,
        )
        logger.info(
            f"WebSocket server started on ws://{self.host}:{self.port}{self.path}"
        )

    async def stop(self):
        """Stop the WebSocket server"""
        if self.server:
            self.server.close()
            await self.server.wait_closed()
            logger.info("WebSocket server stopped")

    async def handle_client(self, websocket: ServerConnection):
        """
        Handle a client connection.

        Args:
            websocket: WebSocket connection
        """
        # Register client
        self.clients.add(websocket)
        client_addr = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        logger.info(f"Client connected: {client_addr}")

        try:
            async for message in websocket:
                await self.message_handler.handle_message(websocket, message)
        except Exception as e:
            logger.error(f"Error handling client {client_addr}: {e}")
        finally:
            # Unregister client
            self.clients.discard(websocket)
            logger.info(f"Client disconnected: {client_addr}")


async def main():
    """Main entry point for running the server standalone"""
    server = AudioWebSocketServer(host="0.0.0.0", port=8080, path="/audio")
    await server.start()

    # Keep server running
    try:
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        await server.stop()


if __name__ == "__main__":
    asyncio.run(main())
