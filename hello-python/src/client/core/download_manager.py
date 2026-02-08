import asyncio
from .. import logger
from . import file_manager
from ..util.error_handler import ErrorType


class DownloadManager:
    """Download manager for orchestrating file downloads from the server.
    Handles GET request sequencing, binary frame assembly, and file writing.
    Matches the Java DownloadManager interface.
    """

    def __init__(self, ws_client, file_manager, chunk_manager=None, error_handler=None):
        self.client = ws_client
        self.file_manager = file_manager
        self.chunk_manager = chunk_manager
        self.error_handler = error_handler
        self.last_error = ""
        self.bytes_downloaded = 0
        self.total_size = 0
        self.request_timeout_ms = 5000
        self.max_retries = 3

    async def download_file(self, stream_id: str, output_path: str, expected_size: int = 0) -> bool:
        """Download a file from the server.

        Args:
            stream_id: Stream identifier to download from
            output_path: Path to write the downloaded file
            expected_size: Expected size of the file (0 if unknown)

        Returns:
            True if download was successful
        """
        logger.info(
            f"Starting download - StreamId: {stream_id}, Output: {output_path}")

        self.bytes_downloaded = 0
        self.total_size = expected_size
        self.last_error = ""

        try:
            # Create output directory if needed
            import os
            output_dir = os.path.dirname(output_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir, exist_ok=True)
                logger.debug(f"Created output directory: {output_dir}")

            downloaded_chunks = []
            offset = 0
            has_more_data = True

            while has_more_data:
                retries = 0
                chunk_data = None

                while retries < self.max_retries and chunk_data is None:
                    # Clear any pending messages
                    # In Python implementation, we might not have a clearMessages() method
                    # So we'll proceed with the download request

                    if not await self._send_get_request(stream_id, offset, file_manager.CHUNK_SIZE):
                        return await self._handle_protocol_error("Failed to send GET request", stream_id)

                    # Receive binary data with timeout
                    try:
                        data = await self._receive_with_timeout(file_manager.CHUNK_SIZE)
                        chunk_data = data
                    except asyncio.TimeoutError:
                        if retries < self.max_retries - 1:
                            logger.warning(
                                f"No data received at offset: {offset}, retry {retries + 1}/{self.max_retries}")
                            await asyncio.sleep(0.1)  # 100ms wait
                        retries += 1
                        continue

                    if chunk_data is None:
                        if await self._is_no_data_error():
                            # Server explicitly said no data available - download complete
                            logger.info(
                                f"Download completed at offset: {offset} (no more data available)")
                            has_more_data = False
                            break
                        retries += 1
                        if retries < self.max_retries:
                            logger.warning(
                                f"No data received at offset: {offset}, retry {retries}/{self.max_retries}")
                            await asyncio.sleep(0.1)  # 100ms wait

                # If we broke out due to no more data, exit the loop
                if not has_more_data:
                    break

                if chunk_data is None:
                    # Failed after all retries
                    error_msg = f"Download failed at offset: {offset} after {self.max_retries} retries"
                    if self.error_handler:
                        self.error_handler.report_error(
                            ErrorType.TIMEOUT_ERROR,
                            error_msg, stream_id, False
                        )
                    logger.error(error_msg)
                    return False

                if chunk_data is not None:
                    downloaded_chunks.append(chunk_data)
                    self.bytes_downloaded += len(chunk_data)
                    offset += len(chunk_data)

                    if len(downloaded_chunks) % 100 == 0:
                        logger.info(
                            f"Download progress: {self.bytes_downloaded} bytes, {len(downloaded_chunks)} chunks")

                    # Check if we received less data than requested - indicates end of file
                    if len(chunk_data) < file_manager.CHUNK_SIZE:
                        logger.info(
                            f"Download completed at offset: {offset} (received partial chunk)")
                        has_more_data = False

            # Write all chunks to file
            if not await self.file_manager.open_for_writing(output_path):
                return await self._handle_protocol_error("Failed to open output file for writing", output_path)

            for chunk in downloaded_chunks:
                if not await self.file_manager.write(chunk):
                    await self.file_manager.close_writer()
                    return await self._handle_protocol_error("Failed to write chunk to file", output_path)

            await self.file_manager.close_writer()

            logger.info(
                f"Download completed - Total chunks: {len(downloaded_chunks)}, Total bytes: {self.bytes_downloaded}")
            return True

        except Exception as e:
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.FILE_IO_ERROR,
                    f"I/O error during download: {str(e)}", stream_id, False
                )
            logger.error(f"Download failed for stream: {stream_id}")
            self.last_error = f"I/O error: {str(e)}"
            return False

    def get_last_error(self) -> str:
        """Get the last error message.

        Returns:
            Error message string
        """
        return self.last_error

    def get_progress(self) -> float:
        """Get download progress (0.0 to 1.0).

        Returns:
            Progress as a fraction
        """
        if self.total_size <= 0:
            return 0.0
        return self.bytes_downloaded / self.total_size

    def get_bytes_downloaded(self) -> int:
        """Get total bytes downloaded.

        Returns:
            Number of bytes downloaded
        """
        return self.bytes_downloaded

    def set_request_timeout(self, timeout_ms: int):
        """Set timeout for GET requests.

        Args:
            timeout_ms: Timeout in milliseconds
        """
        self.request_timeout_ms = timeout_ms

    def set_max_retries(self, max_retries: int):
        """Set maximum retry attempts for failed requests.

        Args:
            max_retries: Maximum number of retry attempts
        """
        self.max_retries = max_retries

    async def handle_server_response(self, message: str):
        """Handle server response message (called from main message router).

        Args:
            message: Server response message
        """
        logger.debug(f"Received server response during download: {message}")
        # Handle responses if needed

    async def _send_get_request(self, stream_id: str, offset: int, length: int) -> bool:
        """Send a GET request for a specific chunk.

        Args:
            stream_id: Stream identifier
            offset: Byte offset to request
            length: Number of bytes to request

        Returns:
            True if request was sent successfully
        """
        try:
            await self.client.send_control_message({
                'type': 'GET',
                'streamId': stream_id,
                'offset': offset,
                'length': length
            })
            logger.debug(
                f"Sent get request - stream: {stream_id}, offset: {offset}, length: {length}")
            return True
        except Exception as e:
            if self.error_handler:
                self.error_handler.report_error(
                    ErrorType.PROTOCOL_ERROR,
                    f"Failed to send GET request: {str(e)}",
                    f"stream={stream_id}, offset={offset}", False
                )
            logger.error("Failed to send GET request")
            return False

    async def _receive_with_timeout(self, chunk_size):
        """Receive data with timeout.

        Args:
            chunk_size: Expected chunk size

        Returns:
            Received data or None if timeout
        """
        try:
            # Clear any pending text messages first
            while True:
                try:
                    # Try to peek at the next message without blocking
                    message = await asyncio.wait_for(
                        self.client.receive_message(),
                        timeout=0.01
                    )
                    # If it's a text message, log and discard it
                    if isinstance(message, str):
                        logger.debug(
                            f"Discarding pending text message before binary receive: {message}")
                    elif isinstance(message, bytes):
                        # Put binary data back into queue for receive_binary to handle
                        await self.client.message_queue.put(message)
                        break
                except asyncio.TimeoutError:
                    # No message available, proceed to wait for binary
                    break

            # Simulate timeout using asyncio.wait_for
            data = await asyncio.wait_for(self.client.receive_binary(), timeout=self.request_timeout_ms/1000.0)
            return data
        except asyncio.TimeoutError:
            raise asyncio.TimeoutError()

    async def _is_no_data_error(self) -> bool:
        """Check if the last message was an error message indicating no data available.

        Returns:
            True if last error message indicates no data available
        """
        # In the current Python WebSocket implementation, we don't have separate
        # text/binary message queues, so we'll return False for now
        # This would need to be implemented based on the specific server response
        return False

    async def _handle_protocol_error(self, message: str, context: str) -> bool:
        """Handle protocol errors with proper error reporting.

        Args:
            message: Error message
            context: Error context

        Returns:
            False (always fails)
        """
        if self.error_handler:
            self.error_handler.report_error(
                ErrorType.PROTOCOL_ERROR, message, context, False)
        logger.error(f"{message} - Context: {context}")
        self.last_error = message
        return False


async def download(ws, stream_id: str, output_path: str, file_size: int):
    """Download file from server (legacy function for compatibility)"""
    from .chunk_manager import ChunkManager  # Import here to avoid circular dependencies
    from ..util.error_handler import ErrorHandler

    file_mgr = file_manager  # Use the imported file_manager module
    chunk_mgr = ChunkManager()  # Create a default chunk manager
    error_handler = ErrorHandler()  # Create a default error handler

    download_manager = DownloadManager(ws, file_mgr, chunk_mgr, error_handler)
    return await download_manager.download_file(stream_id, output_path, file_size)
