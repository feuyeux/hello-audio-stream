// Stream context for managing active audio streams.
// Contains stream metadata and cache file handle.
// Matches Python StreamContext and Java StreamContext functionality.

use std::time::SystemTime;

/// Stream status enumeration
#[derive(Debug, Clone, Copy, PartialEq)]
#[allow(dead_code)]
pub enum StreamStatus {
    Uploading,
    Ready,
    Error,
}

#[allow(dead_code)]
impl StreamStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            StreamStatus::Uploading => "UPLOADING",
            StreamStatus::Ready => "READY",
            StreamStatus::Error => "ERROR",
        }
    }
}

/// Stream context containing metadata and state for a single stream.
#[allow(dead_code)]
pub struct StreamContext {
    pub stream_id: String,
    pub cache_path: String,
    pub mmap_file: Option<std::sync::Arc<super::MemoryMappedCache>>,
    pub current_offset: u64,
    pub total_size: u64,
    pub created_at: SystemTime,
    pub last_accessed_at: SystemTime,
    pub status: StreamStatus,
}

#[allow(dead_code)]
impl StreamContext {
    /// Create a new StreamContext.
    pub fn new(stream_id: String, cache_path: String) -> Self {
        let now = SystemTime::now();
        Self {
            stream_id,
            cache_path,
            mmap_file: None,
            current_offset: 0,
            total_size: 0,
            created_at: now,
            last_accessed_at: now,
            status: StreamStatus::Uploading,
        }
    }

    /// Update last accessed timestamp.
    pub fn update_access_time(&mut self) {
        self.last_accessed_at = SystemTime::now();
    }

    /// Get stream ID.
    pub fn get_stream_id(&self) -> &str {
        &self.stream_id
    }

    /// Get cache path.
    pub fn get_cache_path(&self) -> &str {
        &self.cache_path
    }

    /// Get current offset.
    pub fn get_current_offset(&self) -> u64 {
        self.current_offset
    }

    /// Set current offset.
    pub fn set_current_offset(&mut self, offset: u64) {
        self.current_offset = offset;
    }

    /// Get total size.
    pub fn get_total_size(&self) -> u64 {
        self.total_size
    }

    /// Set total size.
    pub fn set_total_size(&mut self, size: u64) {
        self.total_size = size;
    }

    /// Get created at timestamp.
    pub fn get_created_at(&self) -> SystemTime {
        self.created_at
    }

    /// Get last accessed at timestamp.
    pub fn get_last_accessed_at(&self) -> SystemTime {
        self.last_accessed_at
    }

    /// Get stream status.
    pub fn get_status(&self) -> StreamStatus {
        self.status
    }

    /// Set stream status.
    pub fn set_status(&mut self, status: StreamStatus) {
        self.status = status;
    }

    /// Get memory-mapped file handle.
    pub fn get_mmap_file(&self) -> Option<&std::sync::Arc<super::MemoryMappedCache>> {
        self.mmap_file.as_ref()
    }

    /// Set memory-mapped file handle.
    pub fn set_mmap_file(&mut self, file: Option<std::sync::Arc<super::MemoryMappedCache>>) {
        self.mmap_file = file;
    }
}
