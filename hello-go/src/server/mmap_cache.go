package server

import (
	"fmt"
	"os"
	"sync"
)

const (
	mmapSegment = 1024 * 1024 * 1024 // 1GB
	mmapMaxSize = 8 * mmapSegment    // 8GB
)

// MmapCache manages memory-mapped file I/O for a stream.
// Segment-based: each segment is up to 1GB; max 8GB total.
type MmapCache struct {
	path   string
	file   *os.File
	data   []byte
	size   int64
	active bool
	mu     sync.RWMutex
}

func newMmapCache(path string) *MmapCache {
	return &MmapCache{path: path}
}

// create opens/creates the backing file and optionally pre-allocates space.
func (m *MmapCache) create(initSize int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	_ = os.Remove(m.path) // delete existing
	f, err := os.OpenFile(m.path, os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		return fmt.Errorf("create mmap file: %w", err)
	}
	m.file = f
	m.active = true
	if initSize > 0 {
		if err := f.Truncate(initSize); err != nil {
			return fmt.Errorf("truncate: %w", err)
		}
		m.size = initSize
		if err := m.remap(); err != nil {
			return err
		}
	}
	return nil
}

// write writes data at the given offset, growing the file as needed.
func (m *MmapCache) write(offset int64, data []byte) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.active {
		if err := m.reopenLocked(); err != nil {
			return 0, err
		}
	}
	need := offset + int64(len(data))
	if need > mmapMaxSize {
		return 0, fmt.Errorf("exceeds max size %d", mmapMaxSize)
	}
	if need > m.size {
		if err := m.resizeLocked(need); err != nil {
			return 0, err
		}
	}
	n := copy(m.data[offset:], data)
	return n, nil
}

// read reads up to length bytes from offset.
func (m *MmapCache) read(offset int64, length int) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if !m.active || m.data == nil {
		return nil, fmt.Errorf("cache not open")
	}
	if offset >= m.size {
		return []byte{}, nil
	}
	end := offset + int64(length)
	if end > m.size {
		end = m.size
	}
	buf := make([]byte, end-offset)
	copy(buf, m.data[offset:end])
	return buf, nil
}

// finalize truncates the file to the actual written size and flushes.
func (m *MmapCache) finalize(finalSize int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if err := m.resizeLocked(finalSize); err != nil {
		return err
	}
	if m.data != nil {
		return mflush(m.data)
	}
	return nil
}

// close flushes and releases the mapping.
func (m *MmapCache) close() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.active {
		return
	}
	if m.data != nil {
		_ = mflush(m.data)
		_ = munmap(m.data)
		m.data = nil
	}
	if m.file != nil {
		_ = m.file.Close()
		m.file = nil
	}
	m.active = false
}

func (m *MmapCache) resizeLocked(newSize int64) error {
	if m.data != nil {
		if err := munmap(m.data); err != nil {
			return err
		}
		m.data = nil
	}
	if err := m.file.Truncate(newSize); err != nil {
		return fmt.Errorf("truncate to %d: %w", newSize, err)
	}
	m.size = newSize
	if newSize > 0 {
		return m.remap()
	}
	return nil
}

func (m *MmapCache) reopenLocked() error {
	f, err := os.OpenFile(m.path, os.O_RDWR, 0644)
	if err != nil {
		return fmt.Errorf("reopen: %w", err)
	}
	info, _ := f.Stat()
	m.file = f
	m.size = info.Size()
	m.active = true
	if m.size > 0 {
		return m.remap()
	}
	return nil
}

func (m *MmapCache) remap() error {
	data, err := mmap(m.file, m.size)
	if err != nil {
		return err
	}
	m.data = data
	return nil
}
