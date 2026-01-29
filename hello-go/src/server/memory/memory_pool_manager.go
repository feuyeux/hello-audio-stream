package memory

import (
	"fmt"
	"sync"

	"github.com/feuyeux/hello-mmap/hello-go/src/logger"
)

// MemoryPoolManager manages reusable memory buffers (singleton)
type MemoryPoolManager struct {
	bufferSize       int
	poolSize         int
	availableBuffers chan []byte
	totalBuffers     int
	mutex            sync.Mutex
}

var (
	poolInstance *MemoryPoolManager
	poolOnce     sync.Once
)

// GetMemoryPoolManager returns the singleton instance
func GetMemoryPoolManager(bufferSize, poolSize int) *MemoryPoolManager {
	poolOnce.Do(func() {
		poolInstance = &MemoryPoolManager{
			bufferSize:       bufferSize,
			poolSize:         poolSize,
			availableBuffers: make(chan []byte, poolSize),
			totalBuffers:     0,
		}

		// Pre-allocate buffers
		for i := 0; i < poolSize; i++ {
			buffer := make([]byte, bufferSize)
			poolInstance.availableBuffers <- buffer
			poolInstance.totalBuffers++
		}

		logger.Info(fmt.Sprintf("MemoryPoolManager initialized with %d buffers of %d bytes each", poolSize, bufferSize))
	})
	return poolInstance
}

// AcquireBuffer acquires a buffer from the pool
func (mpm *MemoryPoolManager) AcquireBuffer() []byte {
	select {
	case buffer := <-mpm.availableBuffers:
		return buffer
	default:
		// Pool exhausted, allocate new buffer
		mpm.mutex.Lock()
		buffer := make([]byte, mpm.bufferSize)
		mpm.totalBuffers++
		mpm.mutex.Unlock()
		return buffer
	}
}

// ReleaseBuffer releases a buffer back to the pool
func (mpm *MemoryPoolManager) ReleaseBuffer(buffer []byte) {
	if len(buffer) != mpm.bufferSize {
		logger.Warn(fmt.Sprintf("Buffer size mismatch: expected %d, got %d", mpm.bufferSize, len(buffer)))
		return
	}

	// Clear buffer
	for i := range buffer {
		buffer[i] = 0
	}

	// Try to return to pool (non-blocking)
	select {
	case mpm.availableBuffers <- buffer:
		// Successfully returned to pool
	default:
		// Pool is full, discard buffer
	}
}

// GetAvailableBuffers returns the number of available buffers
func (mpm *MemoryPoolManager) GetAvailableBuffers() int {
	return len(mpm.availableBuffers)
}

// GetTotalBuffers returns the total number of buffers
func (mpm *MemoryPoolManager) GetTotalBuffers() int {
	mpm.mutex.Lock()
	defer mpm.mutex.Unlock()
	return mpm.totalBuffers
}
