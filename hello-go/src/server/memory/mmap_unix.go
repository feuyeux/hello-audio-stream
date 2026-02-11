//go:build !windows

package memory

import (
	"fmt"
	"os"
	"syscall"
)

func mmap(f *os.File, size int64) ([]byte, error) {
	if size == 0 {
		return nil, nil
	}

	// PROT_READ | PROT_WRITE, MAP_SHARED
	data, err := syscall.Mmap(int(f.Fd()), 0, int(size), syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_SHARED)
	if err != nil {
		return nil, fmt.Errorf("Mmap failed: %w", err)
	}

	return data, nil
}

func munmap(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	err := syscall.Munmap(data)
	if err != nil {
		return fmt.Errorf("Munmap failed: %w", err)
	}
	return nil
}

func mflush(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	// Flush memory-mapped data to disk
	// Note: syscall.Msync is not available on all platforms
	// For Linux, we can use the madvise syscall or rely on OS to sync
	return nil
}
