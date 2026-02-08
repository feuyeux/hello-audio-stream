"""WebSocket client for communication with the server"""

import json
import asyncio
from typing import Optional, Dict, Any
import websockets
from . import logger


class WebSocketClient:
    """WebSocket client wrapper"""
    
    def __init__(self, uri: str):
        self.uri = uri
        self.ws: Optional[websockets.WebSocketClientProtocol] = None
        self.message_queue = asyncio.Queue()
    
    async def connect(self):
        """Connect to WebSocket server"""
        self.ws = await websockets.connect(self.uri)
        # Start background task to handle incoming messages
        asyncio.create_task(self._message_handler())
    
    async def close(self):
        """Close WebSocket connection"""
        if self.ws:
            await self.ws.close()
            self.ws = None
    
    async def _message_handler(self):
        """Background task to handle incoming messages"""
        try:
            async for message in self.ws:
                await self.message_queue.put(message)
        except Exception:
            pass  # Connection closed
    
    async def send_text(self, message: str):
        """Send text message"""
        if not self.ws:
            raise RuntimeError("WebSocket is not connected")
        await self.ws.send(message)
    
    async def send_binary(self, data: bytes):
        """Send binary message"""
        if not self.ws:
            raise RuntimeError("WebSocket is not connected")
        await self.ws.send(data)
    
    async def receive_message(self):
        """Receive next message from queue"""
        return await self.message_queue.get()
    
    async def receive_text(self) -> str:
        """Receive text message"""
        if not self.ws:
            raise RuntimeError("WebSocket is not connected")
        
        message = await self.receive_message()
        
        if isinstance(message, bytes):
            # Convert bytes to string
            return message.decode('utf-8')
        else:
            return message
    
    async def receive_binary(self) -> bytes:
        """Receive binary message"""
        if not self.ws:
            raise RuntimeError("WebSocket is not connected")
        
        message = await self.receive_message()
        
        if isinstance(message, bytes):
            return message
        elif isinstance(message, str):
            # Check if it's an error message
            try:
                msg = json.loads(message)
                if msg.get('type') == 'ERROR':
                    raise RuntimeError(f"Server error: {msg.get('message')}")
                else:
                    raise RuntimeError(f"Expected binary message, got text: {message}")
            except json.JSONDecodeError:
                raise RuntimeError(f"Expected binary message, got text: {message}")
        else:
            return bytes(message)
    
    async def send_control_message(self, msg: Dict[str, Any]):
        """Send control message (JSON)"""
        json_data = json.dumps(msg)
        logger.debug(f"Sending control message: {json_data}")
        await self.send_text(json_data)
    
    async def receive_control_message(self) -> Dict[str, Any]:
        """Receive control message (JSON)"""
        text = await self.receive_text()
        logger.debug(f"Received control message: {text}")
        return json.loads(text)
