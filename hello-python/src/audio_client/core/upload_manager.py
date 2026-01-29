"""Upload manager for orchestrating file upload workflow.
Handles the complete upload process: START -> chunks -> STOP.
Matches the Java UploadManager interface.
"""

import asyncio
from .. import logger
from . import file_manager
from ..util.stream_id_generator import StreamIdGenerator
from ..util.error_handler import ErrorType


class UploadManager:
    """Upload manager for orchestrating file upload workflow.
    Handles the complete upload process: START -> chunks -> STOP.
    Matches the Java UploadManager interface.
    """

    def __init__(self, ws_client, file_manager=None, chunk_manager=None,
                 error_handler=None, performance_monitor=None, stream_id_generator=None):
        self.client = ws_client
        # Use default file_manager module
        self.file_manager = file_manager or file_manager
        self.chunk_manager = chunk_manager
        self.error_handler = error_handler
        self.performance_monitor = performance_monitor
        self.stream_id_generator = stream_id_generator or StreamIdGenerator()
        self.progress_callback = None
        self.response_timeout_ms = 5000
        self.upload_delay_ms = 10
        self.message_pause_ms = 0.5  # 500ms in seconds for asyncio.sleep

    async def upload_file(self, file_path: str) -> str:
        """Upload a file to the server.

        Args:
            file_path: Path to the file to upload

        Returns:
            Generated stream ID if successful, empty string if failed
        """
        import os
        if not os.path.exists(file_path):
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.FILE_IO_ERROR,
                    "File not found", file_path, False
                )
            logger.error(f"File not found: {file_path}")
            return ""

        try:
            file_size = os.path.getsize(file_path)
            stream_id = self.stream_id_generator.generate_short()

            logger.info(f"Starting upload - File: {os.path.basename(file_path)}, "
                        f"Size: {file_size} bytes, StreamId: {stream_id}")

            if self.performance_monitor:
                self.performance_monitor.start_upload()

            # Send START message
            if not await self._send_start_message(stream_id):
                return ""

            # Wait for "STARTED" response from server
            try:
                response = await asyncio.wait_for(
                    self.client.receive_control_message(),
                    timeout=self.response_timeout_ms / 1000.0
                )
                if response.get('type') != 'STARTED':
                    logger.error(
                        f"Expected 'STARTED' response, got: {response}")
                    return ""
            except asyncio.TimeoutError:
                logger.error("Timeout waiting for 'started' response")
                return ""

            await asyncio.sleep(self.message_pause_ms)

            # Send file chunks
            if not await self._send_file_chunks(file_path, file_size):
                return ""

            await asyncio.sleep(self.message_pause_ms)

            # Send STOP message
            if not await self._send_stop_message(stream_id):
                return ""

            # Wait for "stopped" response from server
            try:
                response = await asyncio.wait_for(
                    self.client.receive_control_message(),
                    timeout=self.response_timeout_ms / 1000.0
                )
                if response.get('type') != 'STOPPED':
                    logger.warning(
                        f"Expected 'STOPPED' response, got: {response}")
            except asyncio.TimeoutError:
                logger.warning(
                    "Timeout waiting for 'stopped' response (upload may still be complete)")

            if self.performance_monitor:
                self.performance_monitor.end_upload()

            logger.info(
                f"Upload completed successfully with stream ID: {stream_id}")
            return stream_id

        except Exception as e:
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.FILE_IO_ERROR,
                    f"Failed to read file: {str(e)}", file_path, False
                )
            logger.error(f"Upload failed for file: {file_path}")
            return ""

    def set_progress_callback(self, callback):
        """Set callback for upload progress.

        Args:
            callback: Function called with (bytes_uploaded, total_bytes)
        """
        self.progress_callback = callback

    def set_response_timeout(self, timeout_ms: int):
        """Set timeout for server responses.

        Args:
            timeout_ms: Timeout in milliseconds
        """
        self.response_timeout_ms = timeout_ms

    def set_upload_delay(self, delay_ms: int):
        """Set delay between chunk uploads.

        Args:
            delay_ms: Delay in milliseconds
        """
        self.upload_delay_ms = delay_ms

    def handle_server_response(self, message: str):
        """Handle server response message (called from main message router).

        Args:
            message: Server response message
        """
        logger.debug(f"Received server response during upload: {message}")
        # Handle acknowledgments if needed

    async def _send_start_message(self, stream_id: str) -> bool:
        """Send START message to begin streaming.

        Args:
            stream_id: Stream identifier

        Returns:
            True if successful
        """
        try:
            await self.client.send_control_message({
                'type': 'START',
                'streamId': stream_id
            })
            logger.info(f"Sent start message for stream: {stream_id}")
            return True
        except Exception as e:
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.PROTOCOL_ERROR,
                    f"Failed to send start message: {str(e)}", stream_id, False
                )
            logger.error("Failed to send start message")
            return False

    async def _send_file_chunks(self, file_path: str, file_size: int) -> bool:
        """Send file chunks to the server.

        Args:
            file_path: Path to the file
            file_size: Size of the file

        Returns:
            True if successful
        """
        offset = 0
        total_chunks = 0
        total_bytes_transferred = 0

        # Read the entire file
        with open(file_path, 'rb') as f:
            file_data = f.read()

        while offset < len(file_data):
            chunk_length = min(file_manager.CHUNK_SIZE,
                               len(file_data) - offset)
            chunk = file_data[offset:offset + chunk_length]

            await self.client.send_binary(chunk)
            total_bytes_transferred += chunk_length
            total_chunks += 1

            # Call progress callback if set
            if self.progress_callback:
                self.progress_callback(total_bytes_transferred, file_size)

            if self.upload_delay_ms > 0:
                # Convert ms to seconds
                await asyncio.sleep(self.upload_delay_ms / 1000.0)

            offset += chunk_length

            if total_chunks % 100 == 0:
                progress_percent = total_bytes_transferred * 100.0 / file_size
                logger.info(f"Upload progress: {total_bytes_transferred} / {file_size} bytes "
                            f"({progress_percent:.1f}%)")

        logger.info(
            f"Sent {total_chunks} chunks ({total_bytes_transferred} bytes)")
        return True

    async def _send_stop_message(self, stream_id: str) -> bool:
        """Send STOP message to end streaming.

        Args:
            stream_id: Stream identifier

        Returns:
            True if successful
        """
        try:
            await self.client.send_control_message({
                'type': 'STOP',
                'streamId': stream_id
            })
            logger.info("Sent stop message")
            return True
        except Exception as e:
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.PROTOCOL_ERROR,
                    f"Failed to send stop message: {str(e)}", stream_id, False
                )
            logger.error("Failed to send stop message")
            return False


async def upload(ws, file_path: str, file_size: int) -> str:
    """Upload file to server (legacy function for compatibility)"""
    from .chunk_manager import ChunkManager
    from ..util.error_handler import ErrorHandler
    from ..util.performance_monitor import PerformanceMonitor
    from ..util.stream_id_generator import StreamIdGenerator

    chunk_manager = ChunkManager()
    error_handler = ErrorHandler()
    performance_monitor = PerformanceMonitor(file_size)
    stream_id_generator = StreamIdGenerator()

    upload_manager = UploadManager(ws, file_manager, chunk_manager, error_handler,
                                   performance_monitor, stream_id_generator)
    return await upload_manager.upload_file(file_path)
