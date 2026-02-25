use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use anyhow::{anyhow, Result};

use super::mmap_cache::MmapCache;

// ── Constants ─────────────────────────────────────────────────────────────────

pub const MAX_STREAMS: usize = 1000;
const MAX_IDLE_HOURS: u64 = 24;
const MAX_UPLOADING_HOURS: u64 = 1;

// ── StreamStatus ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum StreamStatus {
    Uploading,
    Ready,
    Error,
}

impl std::fmt::Display for StreamStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            StreamStatus::Uploading => write!(f, "UPLOADING"),
            StreamStatus::Ready => write!(f, "READY"),
            StreamStatus::Error => write!(f, "ERROR"),
        }
    }
}

// ── Stream ────────────────────────────────────────────────────────────────────

pub struct Stream {
    pub id: String,
    pub cache: MmapCache,
    pub offset: u64,
    pub created: Instant,
    pub last_access: Instant,
    pub status: StreamStatus,
}

impl Stream {
    fn new(id: String, path: PathBuf) -> Self {
        Self {
            id,
            cache: MmapCache::new(path),
            offset: 0,
            created: Instant::now(),
            last_access: Instant::now(),
            status: StreamStatus::Uploading,
        }
    }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

pub struct Stats {
    pub total: usize,
    pub uploading: usize,
    pub ready: usize,
    pub error: usize,
}

// ── Config ────────────────────────────────────────────────────────────────────

pub struct Config {
    pub cache_dir: PathBuf,
    pub max_streams: usize,
    pub max_idle_hours: u64,
    pub max_uploading_hours: u64,
}

impl Config {
    pub fn new(cache_dir: PathBuf) -> Self {
        Self {
            cache_dir,
            max_streams: MAX_STREAMS,
            max_idle_hours: MAX_IDLE_HOURS,
            max_uploading_hours: MAX_UPLOADING_HOURS,
        }
    }
}

// ── StreamManager ─────────────────────────────────────────────────────────────

pub struct StreamManager {
    config: Config,
    streams: Mutex<HashMap<String, Arc<Mutex<Stream>>>>,
}

impl StreamManager {
    pub fn new(config: Config) -> Self {
        if let Err(e) = std::fs::create_dir_all(&config.cache_dir) {
            eprintln!("Failed to create cache dir: {}", e);
        }
        Self {
            config,
            streams: Mutex::new(HashMap::new()),
        }
    }

    /// Create a new uploading stream. Returns an error if maxStreams reached.
    pub fn create(&self, stream_id: &str) -> Result<()> {
        let mut streams = self.lock();
        if streams.len() >= self.config.max_streams {
            return Err(anyhow!("Max streams ({}) reached", self.config.max_streams));
        }
        if streams.contains_key(stream_id) {
            return Err(anyhow!("Stream already exists: {}", stream_id));
        }
        let path = self.config.cache_dir.join(format!("{}.cache", stream_id));
        let stream = Stream::new(stream_id.to_string(), path);
        stream.cache.create(0)?;
        streams.insert(stream_id.to_string(), Arc::new(Mutex::new(stream)));
        Ok(())
    }

    /// Append binary data to an uploading stream.
    pub fn write(&self, stream_id: &str, data: &[u8]) -> Result<()> {
        let handle = self.get(stream_id)?;
        let mut s = handle.lock().unwrap();
        if s.status != StreamStatus::Uploading {
            return Err(anyhow!("Stream {} is not uploading", stream_id));
        }
        let offset = s.offset;
        let written = s.cache.write(offset, data);
        if written == 0 {
            return Err(anyhow!("Write failed for stream {}", stream_id));
        }
        s.offset += written as u64;
        s.last_access = Instant::now();
        Ok(())
    }

    /// Finalize an uploading stream → status becomes Ready.
    pub fn complete(&self, stream_id: &str) -> Result<()> {
        let handle = self.get(stream_id)?;
        let mut s = handle.lock().unwrap();
        if s.status != StreamStatus::Uploading {
            return Err(anyhow!("Stream {} is not uploading", stream_id));
        }
        let final_size = s.offset;
        s.cache.finalize(final_size)?;
        s.status = StreamStatus::Ready;
        s.last_access = Instant::now();
        Ok(())
    }

    /// Read `length` bytes from a ready stream at `offset`.
    pub fn read(&self, stream_id: &str, offset: u64, length: usize) -> Result<Vec<u8>> {
        let handle = self.get(stream_id)?;
        let mut s = handle.lock().unwrap();
        if s.status != StreamStatus::Ready {
            return Err(anyhow!("Stream {} is not ready", stream_id));
        }
        s.last_access = Instant::now();
        Ok(s.cache.read(offset, length))
    }

    /// Delete a stream and remove its cache file.
    pub fn delete(&self, stream_id: &str) -> Result<()> {
        let handle = {
            let mut streams = self.lock();
            streams
                .remove(stream_id)
                .ok_or_else(|| anyhow!("Stream not found: {}", stream_id))?
        };
        let s = handle.lock().unwrap();
        s.cache.close();
        // Remove cache file
        let path = self.config.cache_dir.join(format!("{}.cache", stream_id));
        let _ = std::fs::remove_file(path);
        Ok(())
    }

    /// Mark a stream as errored (e.g., on connection drop during upload).
    pub fn mark_error(&self, stream_id: &str) {
        if let Ok(handle) = self.get(stream_id) {
            let mut s = handle.lock().unwrap();
            if s.status == StreamStatus::Uploading {
                s.status = StreamStatus::Error;
            }
        }
    }

    /// Get status and size for a stream.
    pub fn status_of(&self, stream_id: &str) -> Result<(StreamStatus, u64)> {
        let handle = self.get(stream_id)?;
        let s = handle.lock().unwrap();
        Ok((s.status, s.offset))
    }

    /// List all stream IDs, comma-separated.
    pub fn list(&self) -> String {
        self.lock().keys().cloned().collect::<Vec<_>>().join(",")
    }

    /// Remove stale streams: idle > 24 h or uploading > 1 h.
    pub fn cleanup(&self) {
        let mut streams = self.lock();
        let now = Instant::now();
        let max_idle = Duration::from_secs(self.config.max_idle_hours * 3600);
        let max_uploading = Duration::from_secs(self.config.max_uploading_hours * 3600);

        streams.retain(|id, handle| {
            let s = handle.lock().unwrap();
            let age = now.duration_since(s.last_access);
            let should_remove = match s.status {
                StreamStatus::Ready | StreamStatus::Error => age > max_idle,
                StreamStatus::Uploading => now.duration_since(s.created) > max_uploading,
            };
            if should_remove {
                s.cache.close();
                let path = self.config.cache_dir.join(format!("{}.cache", id));
                let _ = std::fs::remove_file(path);
                eprintln!("Cleaned up stream: {}", id);
            }
            !should_remove
        });
    }

    /// Aggregate statistics.
    pub fn stats(&self) -> Stats {
        let streams = self.lock();
        let mut s = Stats {
            total: streams.len(),
            uploading: 0,
            ready: 0,
            error: 0,
        };
        for handle in streams.values() {
            match handle.lock().unwrap().status {
                StreamStatus::Uploading => s.uploading += 1,
                StreamStatus::Ready => s.ready += 1,
                StreamStatus::Error => s.error += 1,
            }
        }
        s
    }

    // ── Internal ──────────────────────────────────────────────────────────

    fn get(&self, stream_id: &str) -> Result<Arc<Mutex<Stream>>> {
        self.lock()
            .get(stream_id)
            .cloned()
            .ok_or_else(|| anyhow!("Stream not found: {}", stream_id))
    }

    fn lock(&self) -> MutexGuard<'_, HashMap<String, Arc<Mutex<Stream>>>> {
        self.streams.lock().unwrap()
    }
}
