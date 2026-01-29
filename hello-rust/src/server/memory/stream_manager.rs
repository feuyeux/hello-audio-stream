// Stream manager for managing active audio streams.
// Thread-safe registry of stream contexts.
// Matches Python StreamManager and Java StreamManager functionality.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, SystemTime};

use super::{MemoryMappedCache, StreamContext, StreamStatus};

/// Stream manager for managing multiple concurrent streams.
#[allow(dead_code)]
pub struct StreamManager {
    cache_directory: String,
    streams: Arc<Mutex<HashMap<String, Arc<Mutex<StreamContext>>>>>,
}

#[allow(dead_code)]
impl StreamManager {
    /// Get the singleton instance of StreamManager.
    pub fn instance(cache_directory: String) -> Arc<Self> {
        static INSTANCE: OnceLock<Arc<StreamManager>> = OnceLock::new();

        INSTANCE
            .get_or_init(|| {
                // Create cache directory if it doesn't exist
                if let Err(e) = std::fs::create_dir_all(&cache_directory) {
                    eprintln!("Failed to create cache directory: {:?}", e);
                }

                Arc::new(Self {
                    cache_directory,
                    streams: Arc::new(Mutex::new(HashMap::new())),
                })
            })
            .clone()
    }

    /// Create a new stream.
    pub fn create_stream(&self, stream_id: String) -> bool {
        let mut streams = self.streams.lock().unwrap();

        // Check if stream already exists
        if streams.contains_key(&stream_id) {
            println!("Stream already exists: {}", stream_id);
            return false;
        }

        // Create new stream context
        let cache_path = self.get_cache_path(&stream_id);
        let mut context = StreamContext::new(stream_id.clone(), cache_path.clone());
        context.set_status(StreamStatus::Uploading);
        context.update_access_time();

        // Create memory-mapped cache file
        let mmap_file = Arc::new(MemoryMappedCache::new(cache_path.clone()));
        if !mmap_file.create(0) {
            return false;
        }

        context.set_mmap_file(Some(mmap_file));

        // Add to registry
        streams.insert(stream_id.clone(), Arc::new(Mutex::new(context)));

        println!("Created stream: {} at path: {}", stream_id, cache_path);
        true
    }

    /// Get a stream context.
    pub fn get_stream(&self, stream_id: &str) -> Option<Arc<Mutex<StreamContext>>> {
        let streams = self.streams.lock().unwrap();
        let context = streams.get(stream_id).cloned();

        if let Some(ref ctx) = context {
            ctx.lock().unwrap().update_access_time();
        }

        context
    }

    /// Delete a stream.
    pub fn delete_stream(&self, stream_id: &str) -> bool {
        let mut streams = self.streams.lock().unwrap();

        if let Some(context) = streams.remove(stream_id) {
            let ctx = context.lock().unwrap();

            // Close memory-mapped file
            if let Some(mmap) = ctx.get_mmap_file() {
                mmap.close();
            }

            // Remove cache file
            let cache_path = ctx.get_cache_path();
            if PathBuf::from(cache_path).exists() {
                let _ = std::fs::remove_file(cache_path);
            }

            println!("Deleted stream: {}", stream_id);
            true
        } else {
            println!("Stream not found for deletion: {}", stream_id);
            false
        }
    }

    /// List all active streams.
    pub fn list_active_streams(&self) -> Vec<String> {
        let streams = self.streams.lock().unwrap();
        streams.keys().cloned().collect()
    }

    /// Write a chunk of data to a stream.
    pub fn write_chunk(&self, stream_id: &str, data: &[u8]) -> bool {
        let stream = self.get_stream(stream_id);
        if stream.is_none() {
            eprintln!("Stream not found for write: {}", stream_id);
            return false;
        }

        let stream = stream.unwrap();
        let mut ctx = stream.lock().unwrap();

        if ctx.get_status() != StreamStatus::Uploading {
            eprintln!("Stream {} is not in uploading state", stream_id);
            return false;
        }

        // Write data to memory-mapped file
        let mmap = ctx.get_mmap_file();
        if mmap.is_none() {
            eprintln!("No mmap file for stream {}", stream_id);
            return false;
        }

        let current_offset = ctx.get_current_offset();
        let written = mmap.unwrap().write(current_offset, data);

        if written > 0 {
            let new_offset = current_offset + written as u64;
            let new_total = ctx.get_total_size() + written as u64;
            ctx.set_current_offset(new_offset);
            ctx.set_total_size(new_total);
            ctx.update_access_time();

            println!(
                "Wrote {} bytes to stream {} at offset {}",
                written, stream_id, current_offset
            );
            true
        } else {
            eprintln!("Failed to write data to stream {}", stream_id);
            false
        }
    }

    /// Read a chunk of data from a stream.
    pub fn read_chunk(&self, stream_id: &str, offset: u64, length: usize) -> Vec<u8> {
        let stream = self.get_stream(stream_id);
        if stream.is_none() {
            eprintln!("Stream not found for read: {}", stream_id);
            return Vec::new();
        }

        let stream = stream.unwrap();
        let mut ctx = stream.lock().unwrap();

        let mmap = ctx.get_mmap_file();
        if mmap.is_none() {
            eprintln!("No mmap file for stream {}", stream_id);
            return Vec::new();
        }

        let data = mmap.unwrap().read(offset, length);
        ctx.update_access_time();

        println!(
            "Read {} bytes from stream {} at offset {}",
            data.len(),
            stream_id,
            offset
        );
        data
    }

    /// Finalize a stream.
    pub fn finalize_stream(&self, stream_id: &str) -> bool {
        let stream = self.get_stream(stream_id);
        if stream.is_none() {
            eprintln!("Stream not found for finalization: {}", stream_id);
            return false;
        }

        let stream = stream.unwrap();
        let mut ctx = stream.lock().unwrap();

        if ctx.get_status() != StreamStatus::Uploading {
            println!(
                "Stream {} is not in uploading state for finalization",
                stream_id
            );
            return false;
        }

        let mmap = ctx.get_mmap_file();
        if mmap.is_none() {
            eprintln!("No mmap file for stream {}", stream_id);
            return false;
        }

        if mmap.unwrap().finalize(ctx.get_total_size()) {
            ctx.set_status(StreamStatus::Ready);
            ctx.update_access_time();

            println!(
                "Finalized stream: {} with {} bytes",
                stream_id,
                ctx.get_total_size()
            );
            true
        } else {
            eprintln!(
                "Failed to finalize memory-mapped file for stream {}",
                stream_id
            );
            false
        }
    }

    /// Clean up old streams (older than max_age_hours).
    pub fn cleanup_old_streams(&self, max_age_hours: u64) {
        let streams = self.streams.lock().unwrap();
        let now = SystemTime::now();
        let cutoff = Duration::from_secs(max_age_hours * 3600);

        let to_remove: Vec<String> = streams
            .iter()
            .filter(|(_, ctx)| {
                let ctx = ctx.lock().unwrap();
                if let Ok(age) = now.duration_since(ctx.get_last_accessed_at()) {
                    age > cutoff
                } else {
                    false
                }
            })
            .map(|(id, _)| id.clone())
            .collect();

        for stream_id in to_remove {
            println!("Cleaning up old stream: {}", stream_id);
            self.delete_stream(&stream_id);
        }
    }

    /// Get cache file path for a stream.
    fn get_cache_path(&self, stream_id: &str) -> String {
        format!("{}/{}.cache", self.cache_directory, stream_id)
    }
}
