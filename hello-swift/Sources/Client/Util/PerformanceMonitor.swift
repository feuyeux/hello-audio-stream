import Foundation
import AudioStreamCommon

/// Performance monitoring
class PerformanceMonitor {
    private var uploadStartMs: Int64 = 0
    private var uploadEndMs: Int64 = 0
    private var downloadStartMs: Int64 = 0
    private var downloadEndMs: Int64 = 0
    private var fileSize: Int64 = 0
    
    func setFileSize(_ size: Int64) {
        fileSize = size
    }
    
    func startUpload() {
        uploadStartMs = Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func endUpload() {
        uploadEndMs = Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func startDownload() {
        downloadStartMs = Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func endDownload() {
        downloadEndMs = Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func getReport() -> PerformanceReport {
        let uploadDurationMs = uploadEndMs - uploadStartMs
        let downloadDurationMs = downloadEndMs - downloadStartMs
        let totalDurationMs = downloadEndMs - uploadStartMs
        
        let uploadThroughputMbps = calculateThroughput(bytes: fileSize, durationMs: uploadDurationMs)
        let downloadThroughputMbps = calculateThroughput(bytes: fileSize, durationMs: downloadDurationMs)
        let averageThroughputMbps = calculateThroughput(bytes: fileSize * 2, durationMs: totalDurationMs)
        
        return PerformanceReport(
            uploadDurationMs: uploadDurationMs,
            uploadThroughputMbps: uploadThroughputMbps,
            downloadDurationMs: downloadDurationMs,
            downloadThroughputMbps: downloadThroughputMbps,
            totalDurationMs: totalDurationMs,
            averageThroughputMbps: averageThroughputMbps
        )
    }
    
    func printReport(_ report: PerformanceReport) {
        Logger.info("========================================")
        Logger.info("Phase 4: Performance Report")
        Logger.info("========================================")
        Logger.info("Upload:")
        Logger.info("  Duration: \(report.uploadDurationMs) ms")
        Logger.info(String(format: "  Throughput: %.2f Mbps", report.uploadThroughputMbps))
        Logger.info("Download:")
        Logger.info("  Duration: \(report.downloadDurationMs) ms")
        Logger.info(String(format: "  Throughput: %.2f Mbps", report.downloadThroughputMbps))
        Logger.info("Total:")
        Logger.info("  Duration: \(report.totalDurationMs) ms")
        Logger.info(String(format: "  Average throughput: %.2f Mbps", report.averageThroughputMbps))
        Logger.info("========================================")
    }
    
    private func calculateThroughput(bytes: Int64, durationMs: Int64) -> Double {
        guard durationMs > 0 else { return 0.0 }
        let bits = Double(bytes) * 8.0
        let seconds = Double(durationMs) / 1000.0
        return bits / seconds / 1_000_000.0
    }
}
