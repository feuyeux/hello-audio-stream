package client

import (
	"fmt"
	"os"
	"time"

	"github.com/feuyeux/hello-mmap/hello-go/src/cli"
	"github.com/feuyeux/hello-mmap/hello-go/src/client/core"
	"github.com/feuyeux/hello-mmap/hello-go/src/client/util"
	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

// Run executes the audio client application
func Run() {
	// Parse CLI arguments
	config, err := cli.ParseArgs()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing arguments: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	logger.Init(config.Verbose)

	// Log startup information
	logger.Info("Audio Stream Cache Client - Go Implementation")
	logger.Info(fmt.Sprintf("Server URI: %s", config.Server))
	logger.Info(fmt.Sprintf("Input file: %s", config.Input))
	logger.Info(fmt.Sprintf("Output file: %s", config.Output))

	// Get input file size
	fileSize, err := util.GetFileSize(config.Input)
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to get file size: %v", err))
		os.Exit(1)
	}
	logger.Info(fmt.Sprintf("Input file size: %d bytes", fileSize))

	// Initialize performance monitor
	perf := util.NewPerformanceMonitor(fileSize)

	// Connect to WebSocket server
	logger.Phase("Connecting to Server")
	ws, err := core.Connect(config.Server)
	if err != nil {
		logger.Error(fmt.Sprintf("Failed to connect to server: %v", err))
		os.Exit(1)
	}
	defer ws.Close()
	logger.Info("Successfully connected to server")

	// Upload file
	logger.Phase("Starting Upload")
	perf.StartUpload()
	streamID, err := core.Upload(ws, config.Input, fileSize)
	if err != nil {
		logger.Error(fmt.Sprintf("Upload failed: %v", err))
		os.Exit(1)
	}
	perf.EndUpload()
	logger.Info(fmt.Sprintf("Upload completed successfully with stream ID: %s", streamID))

	// Sleep 2 seconds after upload
	logger.Info("Upload successful, sleeping for 2 seconds...")
	time.Sleep(2 * time.Second)

	// Download file
	logger.Phase("Starting Download")
	perf.StartDownload()
	err = core.Download(ws, streamID, config.Output, fileSize)
	if err != nil {
		logger.Error(fmt.Sprintf("Download failed: %v", err))
		os.Exit(1)
	}
	perf.EndDownload()
	logger.Info("Download completed successfully")

	// Sleep 2 seconds after download
	logger.Info("Download successful, sleeping for 2 seconds...")
	time.Sleep(2 * time.Second)

	// Verify file integrity
	logger.Phase("Verifying File Integrity")
	result, err := util.Verify(config.Input, config.Output)
	if err != nil {
		logger.Error(fmt.Sprintf("Verification error: %v", err))
		os.Exit(1)
	}

	if result.Passed {
		logger.Info("✓ File verification PASSED - Files are identical")
	} else {
		logger.Error("✗ File verification FAILED")
		if result.OriginalSize != result.DownloadedSize {
			logger.Error(fmt.Sprintf("  Reason: File size mismatch (expected %d, got %d)",
				result.OriginalSize, result.DownloadedSize))
		}
		if result.OriginalChecksum != result.DownloadedChecksum {
			logger.Error("  Reason: Checksum mismatch")
		}
		os.Exit(1)
	}

	// Generate performance report
	logger.Phase("Performance Report")
	report := perf.GetReport()
	logger.Info(fmt.Sprintf("Upload Duration: %d ms", report.UploadDurationMs))
	logger.Info(fmt.Sprintf("Upload Throughput: %.2f Mbps", report.UploadThroughputMbps))
	logger.Info(fmt.Sprintf("Download Duration: %d ms", report.DownloadDurationMs))
	logger.Info(fmt.Sprintf("Download Throughput: %.2f Mbps", report.DownloadThroughputMbps))
	logger.Info(fmt.Sprintf("Total Duration: %d ms", report.TotalDurationMs))
	logger.Info(fmt.Sprintf("Average Throughput: %.2f Mbps", report.AverageThroughputMbps))

	// Check performance targets
	if report.UploadThroughputMbps < 100.0 || report.DownloadThroughputMbps < 200.0 {
		logger.Warn("⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)")
	}

	// Disconnect
	logger.Info("Disconnected from server")

	// Log completion
	logger.Phase("Workflow Complete")
	logger.Info(fmt.Sprintf("Successfully uploaded, downloaded, and verified file: %s", config.Input))
}
