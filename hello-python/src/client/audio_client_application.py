#!/usr/bin/env python3

"""
Audio Stream Cache Client - Python Implementation
Main entry point
"""

import asyncio
import sys
from pathlib import Path

from . import logger
from .cli import parse_args
from .core.websocket_client import WebSocketClient
from .core.upload_manager import UploadManager
from .core.download_manager import DownloadManager
from .util.verification_module import verify
from .util.performance_monitor import PerformanceMonitor
from .core import file_manager


async def async_main():
    """Async main function"""
    try:
        # Parse CLI arguments
        args = parse_args()
        
        # Initialize logger
        logger.init(args.verbose)
        
        # Log startup information
        logger.info("Audio Stream Cache Client - Python Implementation")
        logger.info(f"Server URI: {args.server}")
        logger.info(f"Input file: {args.input}")
        logger.info(f"Output file: {args.output}")
        
        # Get input file size
        file_size = await file_manager.get_file_size(args.input)
        logger.info(f"Input file size: {file_size} bytes")
        
        # Initialize performance monitor
        perf = PerformanceMonitor(file_size)
        
        # Ensure output directory exists
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        
        # Connect to WebSocket server
        logger.phase("Connecting to Server")
        ws = WebSocketClient(args.server)
        await ws.connect()
        logger.info("Successfully connected to server")
        
        try:
            # Upload file
            logger.phase("Starting Upload")
            perf.start_upload()
            # Create upload manager with necessary components
            from .core.chunk_manager import ChunkManager
            from .util.error_handler import ErrorHandler
            chunk_manager = ChunkManager()
            error_handler = ErrorHandler()
            upload_manager = UploadManager(ws, file_manager, chunk_manager, error_handler, perf)
            stream_id = await upload_manager.upload_file(args.input)
            perf.end_upload()
            if not stream_id:
                logger.error("Upload failed")
                sys.exit(1)
            logger.info(f"Upload completed successfully with stream ID: {stream_id}")
            
            # Sleep 2 seconds after upload
            logger.info("Upload successful, sleeping for 2 seconds...")
            await asyncio.sleep(2)
            
            # Download file
            logger.phase("Starting Download")
            perf.start_download()
            # Create download manager with necessary components
            from .core.chunk_manager import ChunkManager
            from .util.error_handler import ErrorHandler
            chunk_manager = ChunkManager()
            error_handler = ErrorHandler()
            download_manager = DownloadManager(ws, file_manager, chunk_manager, error_handler)
            download_success = await download_manager.download_file(stream_id, args.output, file_size)
            if not download_success:
                logger.error(f"Download failed: {download_manager.get_last_error()}")
                sys.exit(1)
            perf.end_download()
            logger.info("Download completed successfully")
            
            # Sleep 2 seconds after download
            logger.info("Download successful, sleeping for 2 seconds...")
            await asyncio.sleep(2)
            
            # Verify file integrity
            logger.phase("Verifying File Integrity")
            result = await verify(args.input, args.output)
            
            if result['passed']:
                logger.info("✓ File verification PASSED - Files are identical")
            else:
                logger.error("✗ File verification FAILED")
                if result['original_size'] != result['downloaded_size']:
                    logger.error(f"  Reason: File size mismatch (expected {result['original_size']}, got {result['downloaded_size']})")
                if result['original_checksum'] != result['downloaded_checksum']:
                    logger.error("  Reason: Checksum mismatch")
                sys.exit(1)
            
            # Generate performance report
            logger.phase("Performance Report")
            report = perf.get_report()
            logger.info(f"Upload Duration: {report['upload_duration_ms']} ms")
            logger.info(f"Upload Throughput: {report['upload_throughput_mbps']} Mbps")
            logger.info(f"Download Duration: {report['download_duration_ms']} ms")
            logger.info(f"Download Throughput: {report['download_throughput_mbps']} Mbps")
            logger.info(f"Total Duration: {report['total_duration_ms']} ms")
            logger.info(f"Average Throughput: {report['average_throughput_mbps']} Mbps")
            
            # Check performance targets
            if report['upload_throughput_mbps'] < 100.0 or report['download_throughput_mbps'] < 200.0:
                logger.warning("⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)")
            
            # Disconnect
            await ws.close()
            logger.info("Disconnected from server")
            
            # Log completion
            logger.phase("Workflow Complete")
            logger.info(f"Successfully uploaded, downloaded, and verified file: {args.input}")
            
        finally:
            await ws.close()
    
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


def main():
    """Main entry point"""
    asyncio.run(async_main())


if __name__ == "__main__":
    main()
