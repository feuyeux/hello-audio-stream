package core

const ChunkSize = 65536 // 64KB

// Min returns the minimum of two int64 values
func Min(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}
