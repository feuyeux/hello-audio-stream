package memory

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

// StreamManager manages active audio streams (singleton)
type StreamManager struct {
	cacheDirectory string
	streams        map[string]*StreamContext
	mutex          sync.RWMutex
}

var (
	streamInstance *StreamManager
	streamOnce     sync.Once
)

// GetStreamManager returns singleton instance
func GetStreamManager(cacheDir string) *StreamManager {
	streamOnce.Do(func() {
		streamInstance = &StreamManager{
			cacheDirectory: cacheDir,
			streams:        make(map[string]*StreamContext),
		}

		// Create cache directory
		if err := os.MkdirAll(cacheDir, 0755); err != nil {
			logger.Error(fmt.Sprintf("Failed to create cache directory: %v", err))
		}

		logger.Info(fmt.Sprintf("StreamManager initialized with cache directory: %s", cacheDir))
	})
	return streamInstance
}

// CreateStream creates a new stream
func (sm *StreamManager) CreateStream(streamID string) bool {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	// Check if stream already exists
	if _, exists := sm.streams[streamID]; exists {
		logger.Debug(fmt.Sprintf("Stream already exists: %s", streamID))
		return false
	}

	// Create new stream context
	cachePath := sm.getCachePath(streamID)
	context := NewStreamContext(streamID)
	context.CachePath = cachePath
	context.Status = StatusUploading

	// Create memory-mapped cache file
	mmapFile := NewMemoryMappedCache(cachePath)
	if err := mmapFile.Create(0); err != nil {
		logger.Error(fmt.Sprintf("Failed to create mmap file: %v", err))
		return false
	}
	context.MmapFile = mmapFile

	// Add to registry
	sm.streams[streamID] = context

	logger.Debug(fmt.Sprintf("Created stream: %s at path: %s", streamID, cachePath))
	return true
}

// GetStream retrieves a stream context
func (sm *StreamManager) GetStream(streamID string) *StreamContext {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()

	context := sm.streams[streamID]
	if context != nil {
		context.UpdateAccessTime()
	}
	return context
}

// DeleteStream deletes a stream
func (sm *StreamManager) DeleteStream(streamID string) bool {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	context := sm.streams[streamID]
	if context == nil {
		logger.Debug(fmt.Sprintf("Stream not found for deletion: %s", streamID))
		return false
	}

	// Close memory-mapped file
	if context.MmapFile != nil {
		context.MmapFile.Close()
	}

	// Remove cache file
	if _, err := os.Stat(context.CachePath); err == nil {
		os.Remove(context.CachePath)
	}

	// Remove from registry
	delete(sm.streams, streamID)

	logger.Debug(fmt.Sprintf("Deleted stream: %s", streamID))
	return true
}

// ListActiveStreams returns list of active stream IDs
func (sm *StreamManager) ListActiveStreams() []string {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()

	streams := make([]string, 0, len(sm.streams))
	for streamID := range sm.streams {
		streams = append(streams, streamID)
	}
	return streams
}

// WriteChunk writes data to a stream
func (sm *StreamManager) WriteChunk(streamID string, data []byte) bool {
	stream := sm.GetStream(streamID)
	if stream == nil {
		logger.Debug(fmt.Sprintf("Stream not found for write: %s", streamID))
		return false
	}

	// Lock the stream context for thread-safe access
	stream.Mu.Lock()
	defer stream.Mu.Unlock()

	if stream.Status != StatusUploading {
		logger.Debug(fmt.Sprintf("Stream %s is not in uploading state", streamID))
		return false
	}

	// Write data to memory-mapped file
	n, err := stream.MmapFile.Write(stream.CurrentOffset, data)
	if err != nil {
		logger.Error(fmt.Sprintf("Error writing to stream %s: %v", streamID, err))
		return false
	}

	if n > 0 {
		stream.CurrentOffset += int64(n)
		stream.TotalSize += int64(n)
		stream.UpdateAccessTime()

		logger.Debug(fmt.Sprintf("Wrote %d bytes to stream %s at offset %d", n, streamID, stream.CurrentOffset-int64(n)))
		return true
	}

	logger.Debug(fmt.Sprintf("Failed to write data to stream %s", streamID))
	return false
}

// ReadChunk reads data from a stream
func (sm *StreamManager) ReadChunk(streamID string, offset int64, length int) []byte {
	stream := sm.GetStream(streamID)
	if stream == nil {
		logger.Debug(fmt.Sprintf("Stream not found for read: %s", streamID))
		return []byte{}
	}

	// Lock the stream context for thread-safe access
	stream.Mu.Lock()
	defer stream.Mu.Unlock()

	// Read data from memory-mapped file
	data, err := stream.MmapFile.Read(offset, length)
	if err != nil {
		logger.Error(fmt.Sprintf("Error reading from stream %s: %v", streamID, err))
		return []byte{}
	}

	stream.UpdateAccessTime()
	logger.Debug(fmt.Sprintf("Read %d bytes from stream %s at offset %d", len(data), streamID, offset))
	return data
}

// FinalizeStream finalizes a stream
func (sm *StreamManager) FinalizeStream(streamID string) bool {
	stream := sm.GetStream(streamID)
	if stream == nil {
		logger.Debug(fmt.Sprintf("Stream not found for finalization: %s", streamID))
		return false
	}

	// Lock the stream context for thread-safe access
	stream.Mu.Lock()
	defer stream.Mu.Unlock()

	if stream.Status != StatusUploading {
		logger.Debug(fmt.Sprintf("Stream %s is not in uploading state for finalization", streamID))
		return false
	}

	// Finalize memory-mapped file
	if err := stream.MmapFile.Finalize(stream.TotalSize); err != nil {
		logger.Error(fmt.Sprintf("Failed to finalize memory-mapped file for stream %s: %v", streamID, err))
		return false
	}

	stream.Status = StatusReady
	stream.UpdateAccessTime()

	logger.Debug(fmt.Sprintf("Finalized stream: %s with %d bytes", streamID, stream.TotalSize))
	return true
}

// CleanupOldStreams cleans up streams older than maxAgeHours
func (sm *StreamManager) CleanupOldStreams(maxAgeHours int) {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	now := time.Now()
	cutoff := time.Duration(maxAgeHours) * time.Hour

	var toRemove []string
	for streamID, context := range sm.streams {
		age := now.Sub(context.LastAccessedAt)
		if age > cutoff {
			toRemove = append(toRemove, streamID)
		}
	}

	for _, streamID := range toRemove {
		logger.Debug(fmt.Sprintf("Cleaning up old stream: %s", streamID))
		sm.DeleteStream(streamID)
	}
}

// getCachePath returns cache file path for a stream
func (sm *StreamManager) getCachePath(streamID string) string {
	return filepath.Join(sm.cacheDirectory, streamID+".cache")
}
