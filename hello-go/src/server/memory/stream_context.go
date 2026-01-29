package memory

import (
	"sync"
	"time"
)

// StreamStatus represents the status of a stream
type StreamStatus string

const (
	StatusUploading StreamStatus = "UPLOADING"
	StatusReady     StreamStatus = "READY"
	StatusError     StreamStatus = "ERROR"
)

// StreamContext contains metadata and state for a single stream
// Thread-safe with Mutex for concurrent access
type StreamContext struct {
	StreamID       string
	CachePath      string
	MmapFile       *MemoryMappedCache
	CurrentOffset  int64
	TotalSize      int64
	CreatedAt      time.Time
	LastAccessedAt time.Time
	Status         StreamStatus
	Mu             sync.Mutex // Protects mutable fields
}

// NewStreamContext creates a new stream context
func NewStreamContext(streamID string) *StreamContext {
	now := time.Now()
	return &StreamContext{
		StreamID:       streamID,
		CachePath:      "",
		MmapFile:       nil,
		CurrentOffset:  0,
		TotalSize:      0,
		CreatedAt:      now,
		LastAccessedAt: now,
		Status:         StatusUploading,
	}
}

// UpdateAccessTime updates the last accessed timestamp
func (sc *StreamContext) UpdateAccessTime() {
	sc.LastAccessedAt = time.Now()
}
