"""Performance monitoring for tracking upload/download metrics"""

import time
from typing import Dict


class PerformanceMonitor:
    """Performance monitor for tracking metrics"""
    
    def __init__(self, file_size: int):
        self.file_size = file_size
        self.upload_start_time = 0.0
        self.upload_end_time = 0.0
        self.download_start_time = 0.0
        self.download_end_time = 0.0
    
    def start_upload(self):
        """Start upload timer"""
        self.upload_start_time = time.perf_counter()
    
    def end_upload(self):
        """End upload timer"""
        self.upload_end_time = time.perf_counter()
    
    def start_download(self):
        """Start download timer"""
        self.download_start_time = time.perf_counter()
    
    def end_download(self):
        """End download timer"""
        self.download_end_time = time.perf_counter()
    
    def get_report(self) -> Dict[str, float]:
        """Generate performance report"""
        upload_duration_ms = round((self.upload_end_time - self.upload_start_time) * 1000)
        download_duration_ms = round((self.download_end_time - self.download_start_time) * 1000)
        total_duration_ms = upload_duration_ms + download_duration_ms
        
        # Calculate throughput in Mbps
        file_size_mb = (self.file_size * 8) / (1024 * 1024)  # Convert bytes to megabits
        upload_throughput_mbps = (file_size_mb / upload_duration_ms) * 1000 if upload_duration_ms > 0 else 0
        download_throughput_mbps = (file_size_mb / download_duration_ms) * 1000 if download_duration_ms > 0 else 0
        average_throughput_mbps = (file_size_mb * 2 / total_duration_ms) * 1000 if total_duration_ms > 0 else 0
        
        return {
            'upload_duration_ms': upload_duration_ms,
            'upload_throughput_mbps': round(upload_throughput_mbps, 2),
            'download_duration_ms': download_duration_ms,
            'download_throughput_mbps': round(download_throughput_mbps, 2),
            'total_duration_ms': total_duration_ms,
            'average_throughput_mbps': round(average_throughput_mbps, 2)
        }
