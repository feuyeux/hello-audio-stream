package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/**
 * Performance monitor for tracking transfer metrics.
 * Records timestamps and calculates throughput.
 * Matches the C++ PerformanceMonitor interface.
 */
public class PerformanceMonitor {
    private static final Logger logger = LoggerFactory.getLogger(PerformanceMonitor.class);
    
    // Performance targets
    private static final double UPLOAD_TARGET_MBPS = 100.0;
    private static final double DOWNLOAD_TARGET_MBPS = 200.0;

    private final PerformanceMetrics metrics;

    public PerformanceMonitor() {
        this.metrics = new PerformanceMetrics();
    }

    // Upload metrics

    /**
     * Start tracking upload performance.
     */
    public void startUpload() {
        metrics.uploadStartTime = System.currentTimeMillis();
        logger.debug("Started upload tracking");
    }

    /**
     * End upload tracking and calculate throughput.
     *
     * @param bytes number of bytes transferred
     */
    public void endUpload(long bytes) {
        metrics.uploadEndTime = System.currentTimeMillis();
        metrics.uploadDurationMs = metrics.uploadEndTime - metrics.uploadStartTime;
        metrics.uploadThroughputMbps = calculateThroughputMbps(bytes, metrics.uploadDurationMs);
        
        logger.info("Upload completed: {} bytes in {} ms ({} Mbps)",
                bytes, metrics.uploadDurationMs, String.format("%.2f", metrics.uploadThroughputMbps));
    }

    // Download metrics

    /**
     * Start tracking download performance.
     */
    public void startDownload() {
        metrics.downloadStartTime = System.currentTimeMillis();
        logger.debug("Started download tracking");
    }

    /**
     * End download tracking and calculate throughput.
     *
     * @param bytes number of bytes transferred
     */
    public void endDownload(long bytes) {
        metrics.downloadEndTime = System.currentTimeMillis();
        metrics.downloadDurationMs = metrics.downloadEndTime - metrics.downloadStartTime;
        metrics.downloadThroughputMbps = calculateThroughputMbps(bytes, metrics.downloadDurationMs);
        
        logger.info("Download completed: {} bytes in {} ms ({} Mbps)",
                bytes, metrics.downloadDurationMs, String.format("%.2f", metrics.downloadThroughputMbps));
    }

    // Get metrics

    /**
     * Get the current performance metrics.
     *
     * @return performance metrics
     */
    public PerformanceMetrics getMetrics() {
        return metrics;
    }

    /**
     * Generate a formatted performance report.
     *
     * @return report string
     */
    public String generateReport() {
        StringBuilder report = new StringBuilder();
        report.append("\n=== Performance Report ===\n");
        
        if (metrics.uploadDurationMs > 0) {
            report.append(String.format("Upload Duration: %d ms\n", metrics.uploadDurationMs));
            report.append(String.format("Upload Throughput: %.2f Mbps\n", metrics.uploadThroughputMbps));
        }
        
        if (metrics.downloadDurationMs > 0) {
            report.append(String.format("Download Duration: %d ms\n", metrics.downloadDurationMs));
            report.append(String.format("Download Throughput: %.2f Mbps\n", metrics.downloadThroughputMbps));
        }
        
        report.append(String.format("Performance Targets: Upload >%.0f Mbps, Download >%.0f Mbps\n",
                UPLOAD_TARGET_MBPS, DOWNLOAD_TARGET_MBPS));
        report.append(String.format("Targets Met: %s\n", meetsPerformanceTargets() ? "YES" : "NO"));
        report.append("==========================\n");
        
        return report.toString();
    }

    // Logging functionality

    /**
     * Log metrics to console.
     */
    public void logMetricsToConsole() {
        String report = generateReport();
        System.out.print(report);
        logger.info("Performance metrics logged to console");
    }

    /**
     * Log metrics to a file.
     *
     * @param filePath path to the log file
     */
    public void logMetricsToFile(String filePath) {
        try {
            String report = generateReport();
            Path path = Path.of(filePath);
            
            // Create parent directories if needed
            Path parentDir = path.getParent();
            if (parentDir != null && !Files.exists(parentDir)) {
                Files.createDirectories(parentDir);
            }
            
            // Append to file
            Files.writeString(path, report, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            logger.info("Performance metrics logged to file: {}", filePath);
        } catch (IOException e) {
            logger.error("Failed to log metrics to file: {}", filePath, e);
        }
    }

    // Performance validation

    /**
     * Check if performance targets are met.
     *
     * @return true if both upload and download meet targets
     */
    public boolean meetsPerformanceTargets() {
        boolean uploadMeetsTarget = metrics.uploadThroughputMbps >= UPLOAD_TARGET_MBPS;
        boolean downloadMeetsTarget = metrics.downloadThroughputMbps >= DOWNLOAD_TARGET_MBPS;
        return uploadMeetsTarget && downloadMeetsTarget;
    }

    // Private helper methods

    /**
     * Calculate throughput in Mbps.
     *
     * @param bytes number of bytes transferred
     * @param durationMs duration in milliseconds
     * @return throughput in Mbps
     */
    private double calculateThroughputMbps(long bytes, long durationMs) {
        if (durationMs <= 0) {
            return 0.0;
        }
        // Formula: (bytes * 8) / (durationMs / 1000) / 1,000,000
        return (bytes * 8.0) / (durationMs / 1000.0) / 1_000_000.0;
    }

    /**
     * Format bytes to human-readable string.
     *
     * @param bytes number of bytes
     * @return formatted string
     */
    private String formatBytes(long bytes) {
        if (bytes < 1024) {
            return bytes + " B";
        } else if (bytes < 1024 * 1024) {
            return String.format("%.2f KB", bytes / 1024.0);
        } else if (bytes < 1024 * 1024 * 1024) {
            return String.format("%.2f MB", bytes / (1024.0 * 1024.0));
        } else {
            return String.format("%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0));
        }
    }

    /**
     * Performance metrics data class.
     */
    public static class PerformanceMetrics {
        public long uploadStartTime;
        public long uploadEndTime;
        public long uploadDurationMs;
        public double uploadThroughputMbps;
        
        public long downloadStartTime;
        public long downloadEndTime;
        public long downloadDurationMs;
        public double downloadThroughputMbps;

        public PerformanceMetrics() {
            this.uploadStartTime = 0;
            this.uploadEndTime = 0;
            this.uploadDurationMs = 0;
            this.uploadThroughputMbps = 0.0;
            this.downloadStartTime = 0;
            this.downloadEndTime = 0;
            this.downloadDurationMs = 0;
            this.downloadThroughputMbps = 0.0;
        }

        @Override
        public String toString() {
            return String.format("PerformanceMetrics{uploadDuration=%dms, uploadThroughput=%.2fMbps, " +
                            "downloadDuration=%dms, downloadThroughput=%.2fMbps}",
                    uploadDurationMs, uploadThroughputMbps,
                    downloadDurationMs, downloadThroughputMbps);
        }
    }
}
