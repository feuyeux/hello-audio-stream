#!/usr/bin/env python3
"""
Audio Stream Server - Python Implementation
Main entry point for the server
"""

import asyncio
import argparse
from loguru import logger
import sys

from .network.audio_websocket_server import AudioWebSocketServer
from .memory.stream_manager import StreamManager
from .memory.memory_pool_manager import MemoryPoolManager


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Audio Stream Server - Python Implementation")
    parser.add_argument("--host", default="0.0.0.0", help="Host address to bind to (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080, help="Port number to listen on (default: 8080)")
    parser.add_argument("--path", default="/audio", help="WebSocket endpoint path (default: /audio)")
    parser.add_argument("--cache-dir", default="cache", help="Cache directory for stream files (default: cache)")
    parser.add_argument("--buffer-size", type=int, default=65536, help="Buffer size in bytes (default: 64KB)")
    parser.add_argument("--pool-size", type=int, default=100, help="Number of buffers in pool (default: 100)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    return parser.parse_args()


async def main():
    """Main entry point"""
    args = parse_args()
    
    # Configure logging
    logger.remove()  # Remove default handler
    if args.verbose:
        logger.add(sys.stderr, level="DEBUG")
    else:
        logger.add(sys.stderr, level="INFO")
    
    logger.info("=" * 60)
    logger.info("Audio Stream Server - Python Implementation")
    logger.info("=" * 60)
    
    # Initialize singletons
    logger.info("Initializing server components...")
    stream_manager = StreamManager.get_instance(cache_directory=args.cache_dir)
    memory_pool = MemoryPoolManager.get_instance(buffer_size=args.buffer_size, pool_size=args.pool_size)
    
    logger.info(f"Stream Manager: cache directory = {args.cache_dir}")
    logger.info(f"Memory Pool: {args.pool_size} buffers × {args.buffer_size} bytes")
    
    # Create and start WebSocket server
    server = AudioWebSocketServer(host=args.host, port=args.port, path=args.path)
    await server.start()
    
    logger.info("=" * 60)
    logger.info(f"Server ready at ws://{args.host}:{args.port}{args.path}")
    logger.info("Press Ctrl+C to stop")
    logger.info("=" * 60)
    
    # Keep server running
    try:
        await asyncio.Future()  # Run forever
    except KeyboardInterrupt:
        logger.info("\nShutting down server...")
        await server.stop()
        logger.info("Server stopped")


if __name__ == "__main__":
    asyncio.run(main())
