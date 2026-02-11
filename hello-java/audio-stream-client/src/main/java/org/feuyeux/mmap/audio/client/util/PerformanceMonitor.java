package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Performance monitor for tracking stream metrics.
 * Records timestamps and calculates throughput.
 * Matches the C++ PerformanceMonitor interface.
 */
public class PerformanceMonitor {
    private static final Logger logger = LoggerFactory.getLogger(PerformanceMonitor.class);

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


    // Private helper methods

    /**
     * Calculate throughput in Mbps.
     *
     * @param bytes      number of bytes transferred
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
