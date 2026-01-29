package core

import (
	"fmt"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

func Download(ws *WebSocketClient, streamID string, outputPath string, fileSize int64) error {
	var offset int64 = 0
	var bytesReceived int64 = 0
	lastProgress := 0
	isFirstChunk := true

	for offset < fileSize {
		// Calculate how much data we still need
		remainingBytes := fileSize - offset
		chunkSize := int(Min(int64(ChunkSize), remainingBytes))

		// Send GET message
		offsetPtr := offset
		lengthPtr := chunkSize
		logger.Debug(fmt.Sprintf("Requesting chunk at offset %d, length %d (remaining: %d)", offset, chunkSize, remainingBytes))
		err := ws.SendControlMessage(ControlMessage{
			Type:     "GET",
			StreamID: streamID,
			Offset:   &offsetPtr,
			Length:   &lengthPtr,
		})
		if err != nil {
			return fmt.Errorf("failed to send GET message: %w", err)
		}

		// Receive binary data - one GET request = one binary response
		// The server may send less data than requested
		logger.Debug(fmt.Sprintf("Waiting for binary data at offset %d", offset))
		data, err := ws.ReceiveBinary()
		if err != nil {
			return fmt.Errorf("failed to receive data: %w", err)
		}

		logger.Debug(fmt.Sprintf("Received %d bytes of data", len(data)))

		if len(data) == 0 {
			return fmt.Errorf("no data received for offset %d", offset)
		}

		// Write to file
		if err := WriteChunk(outputPath, data, !isFirstChunk); err != nil {
			return fmt.Errorf("failed to write chunk: %w", err)
		}

		isFirstChunk = false
		offset += int64(len(data))
		bytesReceived += int64(len(data))

		// Report progress
		progress := int(bytesReceived * 100 / fileSize)
		if progress >= lastProgress+25 && progress <= 100 {
			logger.Info(fmt.Sprintf("Download progress: %d/%d bytes (%d%%)", bytesReceived, fileSize, progress))
			lastProgress = progress
		}
	}

	// Ensure 100% is reported
	if lastProgress < 100 {
		logger.Info(fmt.Sprintf("Download progress: %d/%d bytes (100%%)", fileSize, fileSize))
	}

	return nil
}
