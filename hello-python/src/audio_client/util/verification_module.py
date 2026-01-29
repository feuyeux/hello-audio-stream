"""File verification module for comparing original and downloaded files"""

from typing import Dict, Any
from .. import logger
from ..core import file_manager


async def verify(original_path: str, downloaded_path: str) -> Dict[str, Any]:
    """Verify file integrity"""
    logger.info(f"Original file: {original_path}")
    logger.info(f"Downloaded file: {downloaded_path}")
    
    # Get file sizes
    original_size = await file_manager.get_file_size(original_path)
    downloaded_size = await file_manager.get_file_size(downloaded_path)
    
    logger.info(f"Original size: {original_size} bytes")
    logger.info(f"Downloaded size: {downloaded_size} bytes")
    
    # Calculate checksums
    original_checksum = await file_manager.calculate_checksum(original_path)
    downloaded_checksum = await file_manager.calculate_checksum(downloaded_path)
    
    logger.info(f"Original checksum (SHA-256): {original_checksum}")
    logger.info(f"Downloaded checksum (SHA-256): {downloaded_checksum}")
    
    # Compare
    passed = original_size == downloaded_size and original_checksum == downloaded_checksum
    
    return {
        'passed': passed,
        'original_size': original_size,
        'downloaded_size': downloaded_size,
        'original_checksum': original_checksum,
        'downloaded_checksum': downloaded_checksum
    }


class VerificationModule:
    """Module for file verification operations"""
    
    @staticmethod
    async def verify_files(original_path: str, downloaded_path: str) -> Dict[str, Any]:
        """Verify file integrity"""
        return await verify(original_path, downloaded_path)
