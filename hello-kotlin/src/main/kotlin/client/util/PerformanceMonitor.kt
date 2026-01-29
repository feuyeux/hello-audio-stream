package client.util

import Logger
import PerformanceReport

/**
 * Performance monitoring
 */
class PerformanceMonitor {
    private var uploadStartMs: Long = 0
    private var uploadEndMs: Long = 0
    private var downloadStartMs: Long = 0
    private var downloadEndMs: Long = 0
    private var fileSize: Long = 0
    
    fun setFileSize(size: Long) {
        fileSize = size
    }
    
    fun startUpload() {
        uploadStartMs = System.currentTimeMillis()
    }
    
    fun endUpload() {
        uploadEndMs = System.currentTimeMillis()
    }
    
    fun startDownload() {
        downloadStartMs = System.currentTimeMillis()
    }
    
    fun endDownload() {
        downloadEndMs = System.currentTimeMillis()
    }
    
    fun getReport(): PerformanceReport {
        val uploadDurationMs = uploadEndMs - uploadStartMs
        val downloadDurationMs = downloadEndMs - downloadStartMs
        val totalDurationMs = downloadEndMs - uploadStartMs
        
        val uploadThroughputMbps = calculateThroughput(fileSize, uploadDurationMs)
        val downloadThroughputMbps = calculateThroughput(fileSize, downloadDurationMs)
        val averageThroughputMbps = calculateThroughput(fileSize * 2, totalDurationMs)
        
        return PerformanceReport(
            uploadDurationMs = uploadDurationMs,
            uploadThroughputMbps = uploadThroughputMbps,
            downloadDurationMs = downloadDurationMs,
            downloadThroughputMbps = downloadThroughputMbps,
            totalDurationMs = totalDurationMs,
            averageThroughputMbps = averageThroughputMbps
        )
    }
    
    fun printReport(report: PerformanceReport) {
        Logger.info("========================================")
        Logger.info("Phase 4: Performance Report")
        Logger.info("========================================")
        Logger.info("Upload:")
        Logger.info("  Duration: ${report.uploadDurationMs} ms")
        Logger.info("  Throughput: ${"%.2f".format(report.uploadThroughputMbps)} Mbps")
        Logger.info("Download:")
        Logger.info("  Duration: ${report.downloadDurationMs} ms")
        Logger.info("  Throughput: ${"%.2f".format(report.downloadThroughputMbps)} Mbps")
        Logger.info("Total:")
        Logger.info("  Duration: ${report.totalDurationMs} ms")
        Logger.info("  Average throughput: ${"%.2f".format(report.averageThroughputMbps)} Mbps")
        Logger.info("========================================")
    }
    
    private fun calculateThroughput(bytes: Long, durationMs: Long): Double {
        if (durationMs == 0L) return 0.0
        val bits = bytes * 8.0
        val seconds = durationMs / 1000.0
        return bits / seconds / 1_000_000.0
    }
}
