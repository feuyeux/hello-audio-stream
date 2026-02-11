package memory

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
		return nil, fmt.Errorf("CreateFileMapping failed: %w", err)
	}
	defer syscall.CloseHandle(h)

	addr, err := syscall.MapViewOfFile(h, syscall.FILE_MAP_WRITE, 0, 0, uintptr(size))
	if err != nil {
		return nil, fmt.Errorf("MapViewOfFile failed: %w", err)
	}

	// Create a slice from the pointer
	// Note: This is unsafe, but necessary for mmap
	var data []byte

	// Use unsafe.Slice for newer Go versions (1.17+), but to be safe with older pattern:
	// reflect.SliceHeader is deprecated, but widely used.
	// Let's use unsafe conversion which is cleaner in 1.20+
	// data = unsafe.Slice((*byte)(unsafe.Pointer(addr)), size)

	// Since we don't know the exact Go version available (1.25 in go.mod implies we can use modern features)
	data = unsafe.Slice((*byte)(unsafe.Pointer(addr)), int(size))

	return data, nil
}

func munmap(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	addr := unsafe.Pointer(&data[0])
	err := syscall.UnmapViewOfFile(uintptr(addr))
	if err != nil {
		return fmt.Errorf("UnmapViewOfFile failed: %w", err)
	}
	return nil
}

func mflush(data []byte) error {
	if len(data) == 0 {
		return nil
	}
	addr := unsafe.Pointer(&data[0])
	err := syscall.FlushViewOfFile(uintptr(addr), uintptr(len(data)))
	if err != nil {
		return fmt.Errorf("FlushViewOfFile failed: %w", err)
	}
	return nil
}
