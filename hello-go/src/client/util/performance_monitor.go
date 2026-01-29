package util

import (
	"time"
)

type PerformanceMonitor struct {
	fileSize      int64
	uploadStart   time.Time
	uploadEnd     time.Time
	downloadStart time.Time
	downloadEnd   time.Time
}

type PerformanceReport struct {
	UploadDurationMs       int64
	UploadThroughputMbps   float64
	DownloadDurationMs     int64
	DownloadThroughputMbps float64
	TotalDurationMs        int64
	AverageThroughputMbps  float64
}

func NewPerformanceMonitor(fileSize int64) *PerformanceMonitor {
	return &PerformanceMonitor{
		fileSize: fileSize,
	}
}

func (m *PerformanceMonitor) StartUpload() {
	m.uploadStart = time.Now()
}

func (m *PerformanceMonitor) EndUpload() {
	m.uploadEnd = time.Now()
}

func (m *PerformanceMonitor) StartDownload() {
	m.downloadStart = time.Now()
}

func (m *PerformanceMonitor) EndDownload() {
	m.downloadEnd = time.Now()
}

func (m *PerformanceMonitor) GetReport() *PerformanceReport {
	uploadDurationMs := m.uploadEnd.Sub(m.uploadStart).Milliseconds()
	downloadDurationMs := m.downloadEnd.Sub(m.downloadStart).Milliseconds()
	totalDurationMs := uploadDurationMs + downloadDurationMs

	// Throughput (Mbps) = (file_size_bytes * 8) / (duration_ms * 1_000_000)
	uploadThroughputMbps := float64(m.fileSize*8) / float64(uploadDurationMs*1_000_000)
	downloadThroughputMbps := float64(m.fileSize*8) / float64(downloadDurationMs*1_000_000)
	averageThroughputMbps := float64(m.fileSize*2*8) / float64(totalDurationMs*1_000_000)

	return &PerformanceReport{
		UploadDurationMs:       uploadDurationMs,
		UploadThroughputMbps:   uploadThroughputMbps,
		DownloadDurationMs:     downloadDurationMs,
		DownloadThroughputMbps: downloadThroughputMbps,
		TotalDurationMs:        totalDurationMs,
		AverageThroughputMbps:  averageThroughputMbps,
	}
}
