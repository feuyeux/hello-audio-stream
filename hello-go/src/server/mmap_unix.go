//go:build !windows

package server

import (
	"fmt"
	"os"
	"syscall"
)

func mmap(f *os.File, size int64) ([]byte, error) {
	if size == 0 {
		return nil, nil
	}
	data, err := syscall.Mmap(int(f.Fd()), 0, int(size), syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_SHARED)
	if err != nil {
		return nil, fmt.Errorf("mmap: %w", err)
	}
	return data, nil
}

func munmap(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	if err := syscall.Munmap(data); err != nil {
		return fmt.Errorf("munmap: %w", err)
	}
	return nil
}

func mflush(_ []byte) error { return nil } // synced by OS on Linux/macOS
