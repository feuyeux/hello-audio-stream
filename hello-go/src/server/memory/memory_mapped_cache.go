package memory

import (
	"fmt"
	"os"
	"sync"
)

// MemoryMappedCache manages memory-mapped file operations
// Note: For Windows compatibility, we use file I/O instead of platform-specific mmap
// Thread-safe with RWMutex for concurrent access
type MemoryMappedCache struct {
	path   string
	file   *os.File
	size   int64
	isOpen bool
	mu     sync.RWMutex // Protects all fields
}

// NewMemoryMappedCache creates a new memory-mapped cache
func NewMemoryMappedCache(path string) *MemoryMappedCache {
	return &MemoryMappedCache{
		path:   path,
		file:   nil,
		size:   0,
		isOpen: false,
	}
}

// Create creates a new cache file
func (mmc *MemoryMappedCache) Create(initialSize int64) error {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()
	return mmc.createInternal(initialSize)
}

// createInternal creates a new cache file (internal, no lock)
func (mmc *MemoryMappedCache) createInternal(initialSize int64) error {
	// Remove existing file if it exists
	if _, err := os.Stat(mmc.path); err == nil {
		os.Remove(mmc.path)
	}

	// Create new file with read/write permissions
	file, err := os.OpenFile(mmc.path, os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}

	mmc.file = file
	mmc.isOpen = true

	if initialSize > 0 {
		// Set file size
		if err := file.Truncate(initialSize); err != nil {
			return fmt.Errorf("failed to truncate file: %w", err)
		}
		mmc.size = initialSize
	}

	return nil
}

// Open opens an existing cache file
func (mmc *MemoryMappedCache) Open() error {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()
	return mmc.openInternal()
}

// openInternal opens an existing cache file (internal, no lock)
func (mmc *MemoryMappedCache) openInternal() error {
	if _, err := os.Stat(mmc.path); os.IsNotExist(err) {
		return fmt.Errorf("file does not exist: %s", mmc.path)
	}

	file, err := os.OpenFile(mmc.path, os.O_RDWR, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}

	stat, err := file.Stat()
	if err != nil {
		return fmt.Errorf("failed to stat file: %w", err)
	}

	mmc.file = file
	mmc.size = stat.Size()
	mmc.isOpen = true
	return nil
}

// Close closes cache file
func (mmc *MemoryMappedCache) Close() error {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()
	return mmc.closeInternal()
}

// closeInternal closes cache file (internal, no lock)
func (mmc *MemoryMappedCache) closeInternal() error {
	if mmc.isOpen && mmc.file != nil {
		err := mmc.file.Close()
		mmc.file = nil
		mmc.isOpen = false
		return err
	}
	return nil
}

// Write writes data at specified offset
func (mmc *MemoryMappedCache) Write(offset int64, data []byte) (int, error) {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()

	if !mmc.isOpen || mmc.file == nil {
		initialSize := offset + int64(len(data))
		if err := mmc.createInternal(initialSize); err != nil {
			return 0, err
		}
	}

	requiredSize := offset + int64(len(data))
	if requiredSize > mmc.size {
		if err := mmc.file.Truncate(requiredSize); err != nil {
			return 0, fmt.Errorf("failed to truncate file: %w", err)
		}
		mmc.size = requiredSize
	}

	// Write to file at offset
	n, err := mmc.file.WriteAt(data, offset)
	if err != nil {
		return 0, fmt.Errorf("failed to write data: %w", err)
	}

	if offset+int64(n) > mmc.size {
		mmc.size = offset + int64(n)
	}

	return n, nil
}

// Read reads data from specified offset
func (mmc *MemoryMappedCache) Read(offset int64, length int) ([]byte, error) {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()

	if !mmc.isOpen || mmc.file == nil {
		if err := mmc.openInternal(); err != nil {
			return nil, err
		}
	}

	if offset >= mmc.size {
		return []byte{}, nil
	}

	actualLength := length
	if offset+int64(length) > mmc.size {
		actualLength = int(mmc.size - offset)
	}

	// Read from file at offset
	data := make([]byte, actualLength)
	n, err := mmc.file.ReadAt(data, offset)
	if err != nil {
		return nil, fmt.Errorf("read error: %w", err)
	}

	return data[:n], nil
}

// Resize resizes cache file
func (mmc *MemoryMappedCache) Resize(newSize int64) error {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()
	return mmc.resizeInternal(newSize)
}

// resizeInternal resizes cache file (internal, no lock)
func (mmc *MemoryMappedCache) resizeInternal(newSize int64) error {
	if !mmc.isOpen {
		return fmt.Errorf("file not open for resize")
	}

	if newSize == mmc.size {
		return nil
	}

	if err := mmc.file.Truncate(newSize); err != nil {
		return fmt.Errorf("failed to truncate file: %w", err)
	}

	mmc.size = newSize
	return nil
}

// Finalize finalizes cache file
func (mmc *MemoryMappedCache) Finalize(finalSize int64) error {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()

	if !mmc.isOpen {
		return fmt.Errorf("file not open for finalization")
	}

	if err := mmc.resizeInternal(finalSize); err != nil {
		return err
	}

	// Sync to disk
	if err := mmc.file.Sync(); err != nil {
		return fmt.Errorf("failed to sync file: %w", err)
	}

	return nil
}

// GetSize returns to current size
func (mmc *MemoryMappedCache) GetSize() int64 {
	mmc.mu.RLock()
	defer mmc.mu.RUnlock()
	return mmc.size
}

// GetPath returns to file path
func (mmc *MemoryMappedCache) GetPath() string {
	return mmc.path
}

// IsOpen returns whether the file is open
func (mmc *MemoryMappedCache) IsOpen() bool {
	mmc.mu.RLock()
	defer mmc.mu.RUnlock()
	return mmc.isOpen
}
