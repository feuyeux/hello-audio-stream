package server

import (
	"fmt"
	"os"
	"syscall"
	"unsafe"
)

func mmap(f *os.File, size int64) ([]byte, error) {
	if size == 0 {
		return nil, nil
	}
	h, err := syscall.CreateFileMapping(syscall.Handle(f.Fd()), nil, syscall.PAGE_READWRITE, 0, 0, nil)
	if err != nil {
		return nil, fmt.Errorf("CreateFileMapping: %w", err)
	}
	defer syscall.CloseHandle(h)
	addr, err := syscall.MapViewOfFile(h, syscall.FILE_MAP_WRITE, 0, 0, uintptr(size))
	if err != nil {
		return nil, fmt.Errorf("MapViewOfFile: %w", err)
	}
	return unsafe.Slice((*byte)(unsafe.Pointer(addr)), int(size)), nil
}

func munmap(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	if err := syscall.UnmapViewOfFile(uintptr(unsafe.Pointer(&data[0]))); err != nil {
		return fmt.Errorf("UnmapViewOfFile: %w", err)
	}
	return nil
}

func mflush(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	if err := syscall.FlushViewOfFile(uintptr(unsafe.Pointer(&data[0])), uintptr(len(data))); err != nil {
		return fmt.Errorf("FlushViewOfFile: %w", err)
	}
	return nil
}
