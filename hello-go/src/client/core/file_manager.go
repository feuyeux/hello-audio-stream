package core

import (
	"fmt"
	"os"
	"path/filepath"
)

// ReadChunk reads a chunk of data from a file at the specified offset
func ReadChunk(path string, offset int64, size int) ([]byte, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	_, err = file.Seek(offset, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to seek file: %w", err)
	}

	buffer := make([]byte, size)
	n, err := file.Read(buffer)
	if err != nil && err.Error() != "EOF" {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	return buffer[:n], nil
}

// WriteChunk writes data to a file
func WriteChunk(path string, data []byte, append bool) error {
	// Ensure parent directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	flags := os.O_CREATE | os.O_WRONLY
	if append {
		flags |= os.O_APPEND
	} else {
		flags |= os.O_TRUNC
	}

	file, err := os.OpenFile(path, flags, 0644)
	if err != nil {
		return fmt.Errorf("failed to open file for writing: %w", err)
	}
	defer file.Close()

	_, err = file.Write(data)
	if err != nil {
		return fmt.Errorf("failed to write to file: %w", err)
	}

	return nil
}
