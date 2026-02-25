package server

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const (
	maxStreams        = 1000
	maxIdleHours      = 24
	maxUploadingHours = 1
)

// StreamStatus represents the lifecycle state of a stream.
type StreamStatus string

const (
	StatusUploading StreamStatus = "UPLOADING"
	StatusReady     StreamStatus = "READY"
	StatusError     StreamStatus = "ERROR"
)

// Stream holds the state for a single audio stream.
type Stream struct {
	id         string
	path       string
	cache      *MmapCache
	offset     int64
	created    time.Time
	lastAccess time.Time
	status     StreamStatus
	mu         sync.Mutex
}

// Stats summarises the current StreamManager state.
type Stats struct {
	Total     int
	Uploading int
	Ready     int
	Error     int
}

// StreamManager manages all active streams.
// All public methods are thread-safe.
type StreamManager struct {
	cacheDir string
	streams  map[string]*Stream
	mu       sync.RWMutex // protects streams map
}

func newStreamManager(cacheDir string) *StreamManager {
	if err := os.MkdirAll(cacheDir, fs.ModePerm); err != nil {
		panic(fmt.Sprintf("cannot create cache dir: %v", err))
	}
	return &StreamManager{
		cacheDir: cacheDir,
		streams:  make(map[string]*Stream),
	}
}

// create registers a new stream and opens its backing mmap cache.
func (sm *StreamManager) create(id string) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if _, exists := sm.streams[id]; exists {
		return false
	}
	if len(sm.streams) >= maxStreams {
		return false
	}
	path := filepath.Join(sm.cacheDir, id+".cache")
	cache := newMmapCache(path)
	if err := cache.create(0); err != nil {
		return false
	}
	sm.streams[id] = &Stream{
		id:         id,
		path:       path,
		cache:      cache,
		created:    time.Now(),
		lastAccess: time.Now(),
		status:     StatusUploading,
	}
	return true
}

// get returns the stream and updates its last-access time.
func (sm *StreamManager) get(id string) *Stream {
	sm.mu.RLock()
	s := sm.streams[id]
	sm.mu.RUnlock()
	if s != nil {
		s.mu.Lock()
		s.lastAccess = time.Now()
		s.mu.Unlock()
	}
	return s
}

// complete transitions a stream from UPLOADING to READY.
func (sm *StreamManager) complete(id string) bool {
	s := sm.get(id)
	if s == nil {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.status != StatusUploading {
		return false
	}
	if err := s.cache.finalize(s.offset); err != nil {
		s.status = StatusError
		return false
	}
	s.status = StatusReady
	return true
}

// write appends data to an uploading stream.
func (sm *StreamManager) write(id string, data []byte) {
	s := sm.get(id)
	if s == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.status != StatusUploading {
		return
	}
	n, err := s.cache.write(s.offset, data)
	if err != nil {
		s.status = StatusError
		return
	}
	s.offset += int64(n)
}

// read reads data from a stream at the given offset.
func (sm *StreamManager) read(id string, offset int64, length int) []byte {
	s := sm.get(id)
	if s == nil {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := s.cache.read(offset, length)
	if err != nil {
		return nil
	}
	return data
}

// delete removes a stream and its backing file.
func (sm *StreamManager) delete(id string) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	s, ok := sm.streams[id]
	if !ok {
		return
	}
	delete(sm.streams, id)
	s.cache.close()
	_ = os.Remove(s.path)
}

// markError transitions an UPLOADING stream to ERROR (on disconnect).
func (sm *StreamManager) markError(id string) {
	s := sm.get(id)
	if s == nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.status == StatusUploading {
		s.status = StatusError
	}
}

// list returns all known stream IDs.
func (sm *StreamManager) list() []string {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	ids := make([]string, 0, len(sm.streams))
	for id := range sm.streams {
		ids = append(ids, id)
	}
	return ids
}

// cleanup removes idle and stale streams.
func (sm *StreamManager) cleanup() {
	now := time.Now()
	sm.mu.Lock()
	var toDelete []string
	for id, s := range sm.streams {
		s.mu.Lock()
		idle := now.Sub(s.lastAccess)
		uploading := s.status == StatusUploading
		s.mu.Unlock()
		if idle > maxIdleHours*time.Hour ||
			(uploading && idle > maxUploadingHours*time.Hour) {
			toDelete = append(toDelete, id)
		}
	}
	sm.mu.Unlock()
	for _, id := range toDelete {
		sm.delete(id)
	}
}

// stats returns a summary of stream counts by status.
func (sm *StreamManager) stats() Stats {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	s := Stats{Total: len(sm.streams)}
	for _, stream := range sm.streams {
		stream.mu.Lock()
		switch stream.status {
		case StatusUploading:
			s.Uploading++
		case StatusReady:
			s.Ready++
		case StatusError:
			s.Error++
		}
		stream.mu.Unlock()
	}
	return s
}
