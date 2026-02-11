package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * Verification module for file integrity checking.
 * Computes checksums and compares files using various hash algorithms.
 * Matches the C++ VerificationModule interface.
 */
public class VerificationModule {
    private static final Logger logger = LoggerFactory.getLogger(VerificationModule.class);

    /**
     * Generate a detailed verification report comparing two files.
     *
     * @param originalFile   path to original file
     * @param downloadedFile path to downloaded file
     * @return verification report with detailed comparison results
     * @throws IOException if files cannot be read
     */
    public VerificationReport generateReport(Path originalFile, Path downloadedFile) throws IOException {
        if (!Files.exists(originalFile)) {
            throw new IOException("File not found: " + originalFile);
        }
        if (!Files.exists(downloadedFile)) {
            throw new IOException("File not found: " + downloadedFile);
        }

        logger.info("Comparing files: {} vs {}", originalFile.getFileName(), downloadedFile.getFileName());

        long originalSize = Files.size(originalFile);
        long downloadedSize = Files.size(downloadedFile);

        byte[] originalData = Files.readAllBytes(originalFile);
        byte[] downloadedData = Files.readAllBytes(downloadedFile);

        String originalMd5 = calculateMD5(originalData);
        String downloadedMd5 = calculateMD5(downloadedData);
        String originalSha1 = calculateSHA1(originalData);
        String downloadedSha1 = calculateSHA1(downloadedData);
        String originalSha256 = calculateSHA256(originalData);
        String downloadedSha256 = calculateSHA256(downloadedData);

        boolean sizeMatch = originalSize == downloadedSize;
        boolean md5Match = originalMd5.equals(downloadedMd5);
        boolean sha1Match = originalSha1.equals(downloadedSha1);
        boolean sha256Match = originalSha256.equals(downloadedSha256);
        boolean verificationPassed = sizeMatch && md5Match && sha1Match && sha256Match;

        int firstDifference = -1;
        int totalDifferences = 0;

        if (!verificationPassed) {
            int minLength = Math.min(originalData.length, downloadedData.length);
            for (int i = 0; i < minLength; i++) {
                if (originalData[i] != downloadedData[i]) {
                    totalDifferences++;
                    if (firstDifference == -1) {
                        firstDifference = i;
                    }
                }
            }
            if (originalData.length != downloadedData.length) {
                totalDifferences += Math.abs(originalData.length - downloadedData.length);
            }
        }

        // Use SHA-256 as the primary checksum (matching C++ implementation)
        String errorMessage = null;
        if (!verificationPassed) {
            errorMessage = String.format("Verification failed: size match=%s, MD5 match=%s, SHA-1 match=%s, SHA-256 match=%s",
                    sizeMatch, md5Match, sha1Match, sha256Match);
        }

        VerificationReport report = new VerificationReport(
                originalFile.toString(), downloadedFile.toString(),
                originalSize, downloadedSize,
                originalSha256, downloadedSha256,
                verificationPassed, errorMessage,
                originalMd5, downloadedMd5,
                originalSha1, downloadedSha1,
                originalSha256, downloadedSha256,
                sizeMatch, md5Match, sha1Match, sha256Match,
                firstDifference, totalDifferences
        );

        logger.info("Verification result: {}", report);

        return report;
    }

    // Private helper methods for checksum calculation

    private String calculateMD5(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] hash = md.digest(data);
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("MD5 algorithm not available", e);
        }
    }

    private String calculateSHA1(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-1");
            byte[] hash = md.digest(data);
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-1 algorithm not available", e);
        }
    }

    private String calculateSHA256(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(data);
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not available", e);
        }
    }

    /**
     * Verification report containing detailed comparison results.
     * Matches the C++ VerificationReport structure.
     */
    public static class VerificationReport {
        private final String originalPath;
        private final String downloadedPath;
        private final long originalSize;
        private final long downloadedSize;
        private final String originalChecksum;  // SHA-256
        private final String downloadedChecksum;  // SHA-256
        private final boolean verificationPassed;
        private final String errorMessage;

        // Additional fields for detailed comparison
        private final String originalMd5;
        private final String downloadedMd5;
        private final String originalSha1;
        private final String downloadedSha1;
        private final String originalSha256;
        private final String downloadedSha256;
        private final boolean sizeMatch;
        private final boolean md5Match;
        private final boolean sha1Match;
        private final boolean sha256Match;
        private final int firstDifference;
        private final int totalDifferences;

        public VerificationReport(String originalPath, String downloadedPath,
                                  long originalSize, long downloadedSize,
                                  String originalChecksum, String downloadedChecksum,
                                  boolean verificationPassed, String errorMessage,
                                  String originalMd5, String downloadedMd5,
                                  String originalSha1, String downloadedSha1,
                                  String originalSha256, String downloadedSha256,
                                  boolean sizeMatch, boolean md5Match, boolean sha1Match, boolean sha256Match,
                                  int firstDifference, int totalDifferences) {
            this.originalPath = originalPath;
            this.downloadedPath = downloadedPath;
            this.originalSize = originalSize;
            this.downloadedSize = downloadedSize;
            this.originalChecksum = originalChecksum;
            this.downloadedChecksum = downloadedChecksum;
            this.verificationPassed = verificationPassed;
            this.errorMessage = errorMessage;
            this.originalMd5 = originalMd5;
            this.downloadedMd5 = downloadedMd5;
            this.originalSha1 = originalSha1;
            this.downloadedSha1 = downloadedSha1;
            this.originalSha256 = originalSha256;
            this.downloadedSha256 = downloadedSha256;
            this.sizeMatch = sizeMatch;
            this.md5Match = md5Match;
            this.sha1Match = sha1Match;
            this.sha256Match = sha256Match;
            this.firstDifference = firstDifference;
            this.totalDifferences = totalDifferences;
        }

        public boolean isVerificationPassed() {
            return verificationPassed;
        }

        /**
         * Print detailed verification report to console.
         */
        public void printReport() {
            System.out.println("\n=== File Verification Report ===");
            System.out.println("Original File: " + originalPath);
            System.out.println("Downloaded File: " + downloadedPath);
            System.out.println();
            System.out.println("Original Size: " + originalSize + " bytes");
            System.out.println("Downloaded Size: " + downloadedSize + " bytes");
            System.out.println("Size Match: " + sizeMatch);
            System.out.println();
            System.out.println("Original MD5: " + originalMd5);
            System.out.println("Downloaded MD5: " + downloadedMd5);
            System.out.println("MD5 Match: " + md5Match);
            System.out.println();
            System.out.println("Original SHA-1: " + originalSha1);
            System.out.println("Downloaded SHA-1: " + downloadedSha1);
            System.out.println("SHA-1 Match: " + sha1Match);
            System.out.println();
            System.out.println("Original SHA-256: " + originalSha256);
            System.out.println("Downloaded SHA-256: " + downloadedSha256);
            System.out.println("SHA-256 Match: " + sha256Match);
            System.out.println();
            System.out.println("Verification Passed: " + verificationPassed);

            if (!verificationPassed) {
                System.out.println("First Difference at byte: " + firstDifference);
                System.out.println("Total Differences: " + totalDifferences);
                if (errorMessage != null) {
                    System.out.println("Error: " + errorMessage);
                }
            }

            System.out.println("================================\n");
        }

        @Override
        public String toString() {
            return String.format("VerificationReport{verificationPassed=%s, sizeMatch=%s, md5Match=%s, sha1Match=%s, sha256Match=%s, " +
                            "totalDifferences=%d, firstDifference=%d}",
                    verificationPassed, sizeMatch, md5Match, sha1Match, sha256Match,
                    totalDifferences, firstDifference);
        }
    }
}
