package util

import (
	"fmt"
	"strings"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

type VerificationResult struct {
	Passed             bool
	OriginalSize       int64
	DownloadedSize     int64
	OriginalChecksum   string
	DownloadedChecksum string
}

func Verify(originalPath string, downloadedPath string) (*VerificationResult, error) {
	logger.Info(fmt.Sprintf("Original file: %s", originalPath))
	logger.Info(fmt.Sprintf("Downloaded file: %s", downloadedPath))

	// Get file sizes
	originalSize, err := GetFileSize(originalPath)
	if err != nil {
		return nil, fmt.Errorf("failed to get original file size: %w", err)
	}

	downloadedSize, err := GetFileSize(downloadedPath)
	if err != nil {
		return nil, fmt.Errorf("failed to get downloaded file size: %w", err)
	}

	logger.Info(fmt.Sprintf("Original size: %d bytes", originalSize))
	logger.Info(fmt.Sprintf("Downloaded size: %d bytes", downloadedSize))

	// Compute checksums
	originalChecksum, err := ComputeSHA256(originalPath)
	if err != nil {
		return nil, fmt.Errorf("failed to compute original checksum: %w", err)
	}

	downloadedChecksum, err := ComputeSHA256(downloadedPath)
	if err != nil {
		return nil, fmt.Errorf("failed to compute downloaded checksum: %w", err)
	}

	logger.Info(fmt.Sprintf("Original checksum (SHA-256): %s", originalChecksum))
	logger.Info(fmt.Sprintf("Downloaded checksum (SHA-256): %s", downloadedChecksum))

	// Compare
	passed := originalSize == downloadedSize &&
		strings.EqualFold(originalChecksum, downloadedChecksum)

	return &VerificationResult{
		Passed:             passed,
		OriginalSize:       originalSize,
		DownloadedSize:     downloadedSize,
		OriginalChecksum:   originalChecksum,
		DownloadedChecksum: downloadedChecksum,
	}, nil
}
