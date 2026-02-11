package memory

import (
	"fmt"
	"os"
	"sync"
)

// MemoryMappedCache manages memory-mapped file operations
// Follows the unified mmap implementation specification v2.0.0
type MemoryMappedCache struct {
	path   string
	file   *os.File
	data   []byte // Mapped memory slice
	size   int64
	isOpen bool
	mu     sync.RWMutex // Protects all fields
}

// NewMemoryMappedCache creates a new memory-mapped cache
func NewMemoryMappedCache(path string) *MemoryMappedCache {
	return &MemoryMappedCache{
		path:   path,
		file:   nil,
		data:   nil,
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

		// Map file
		if err := mmc.mapFile(); err != nil {
			return err
		}
	} else {
		mmc.size = 0
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
		if err := mmc.resizeInternal(requiredSize); err != nil {
			return 0, err
		}
	}

	// Write to memory map
	n := copy(mmc.data[offset:], data)
	return n, nil
}

// Read reads data from specified offset
func (mmc *MemoryMappedCache) Read(offset int64, length int) ([]byte, error) {
	mmc.mu.Lock()
	defer mmc.mu.Unlock()

	if !mmc.isOpen || mmc.file == nil {
		return nil, fmt.Errorf("file not open for reading")
	}

	if offset >= mmc.size {
		return []byte{}, nil
	}

	actualLength := length
	if offset+int64(length) > mmc.size {
		actualLength = int(mmc.size - offset)
	}

	// Read from memory map
	data := make([]byte, actualLength)
	copy(data, mmc.data[offset:offset+int64(actualLength)])

	return data, nil
}

// resizeInternal resizes cache file (internal, no lock)
func (mmc *MemoryMappedCache) resizeInternal(newSize int64) error {
	if !mmc.isOpen {
		return fmt.Errorf("file not open for resize")
	}

	if newSize == mmc.size {
		return nil
	}

	// Unmap first
	if err := mmc.unmapFile(); err != nil {
		return err
	}

	if err := mmc.file.Truncate(newSize); err != nil {
		return fmt.Errorf("failed to truncate file: %w", err)
	}

	mmc.size = newSize

	// Remap
	if newSize > 0 {
		if err := mmc.mapFile(); err != nil {
			return err
		}
	}

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

	// Flush
	if mmc.data != nil {
		if err := mflush(mmc.data); err != nil {
			return err
		}
	}

	// Sync to disk
	if err := mmc.file.Sync(); err != nil {
		return fmt.Errorf("failed to sync file: %w", err)
	}

	return nil
}

// Helper methods

func (mmc *MemoryMappedCache) mapFile() error {
	data, err := mmap(mmc.file, mmc.size)
	if err != nil {
		return err
	}
	mmc.data = data
	return nil
}

func (mmc *MemoryMappedCache) unmapFile() error {
	if mmc.data != nil {
		err := munmap(mmc.data)
		mmc.data = nil
		return err
	}
	return nil
}
