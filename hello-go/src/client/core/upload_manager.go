package core

import (
	"fmt"

	"github.com/feuyeux/hello-mmap/hello-go/src/client/util"
	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

func Upload(ws *WebSocketClient, filePath string, fileSize int64) (string, error) {
	// Generate unique stream ID
	streamID := util.GenerateStreamID()
	logger.Info(fmt.Sprintf("Generated stream ID: %s", streamID))

	// Send START message
	err := ws.SendControlMessage(ControlMessage{
		Type:     "START",
		StreamID: streamID,
	})
	if err != nil {
		return "", fmt.Errorf("failed to send START message: %w", err)
	}

	// Wait for START_ACK
	response, err := ws.ReceiveControlMessage()
	if err != nil {
		return "", fmt.Errorf("failed to receive START_ACK: %w", err)
	}
	if response.Type != "STARTED" {
		return "", fmt.Errorf("unexpected response to START: %s", response.Type)
	}

	// Upload file in chunks
	// Use smaller chunk size (8KB) to avoid WebSocket frame fragmentation
	// which the Java server doesn't handle properly
	const uploadChunkSize = 8192
	var offset int64 = 0
	var bytesSent int64 = 0
	lastProgress := 0

	for offset < fileSize {
		chunkSize := int(Min(int64(uploadChunkSize), fileSize-offset))
		chunk, err := ReadChunk(filePath, offset, chunkSize)
		if err != nil {
			return "", fmt.Errorf("failed to read chunk: %w", err)
		}

		if err := ws.SendBinary(chunk); err != nil {
			return "", fmt.Errorf("failed to send chunk: %w", err)
		}

		offset += int64(len(chunk))
		bytesSent += int64(len(chunk))

		// Report progress
		progress := int(bytesSent * 100 / fileSize)
		if progress >= lastProgress+25 && progress <= 100 {
			logger.Info(fmt.Sprintf("Upload progress: %d/%d bytes (%d%%)", bytesSent, fileSize, progress))
			lastProgress = progress
		}
	}

	// Ensure 100% is reported
	if lastProgress < 100 {
		logger.Info(fmt.Sprintf("Upload progress: %d/%d bytes (100%%)", fileSize, fileSize))
	}

	// Send STOP message
	err = ws.SendControlMessage(ControlMessage{
		Type:     "STOP",
		StreamID: streamID,
	})
	if err != nil {
		return "", fmt.Errorf("failed to send STOP message: %w", err)
	}

	// Wait for STOPPED
	response, err = ws.ReceiveControlMessage()
	if err != nil {
		return "", fmt.Errorf("failed to receive STOPPED: %w", err)
	}
	if response.Type != "STOPPED" {
		return "", fmt.Errorf("unexpected response to STOP: %s", response.Type)
	}

	return streamID, nil
}
