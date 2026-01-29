// Memory pool manager for efficient buffer reuse.
// Pre-allocates buffers to minimize allocation overhead.
// Implemented as a singleton to ensure a single shared pool across all streams.
// Matches C++ MemoryPoolManager and Java MemoryPoolManager functionality.

use std::sync::{Arc, Mutex};

/// Memory pool manager singleton.
#[allow(dead_code)]
pub struct MemoryPoolManager {
    buffer_size: usize,
    pool_size: usize,
    available_buffers: Mutex<Vec<Vec<u8>>>,
    total_buffers: Mutex<usize>,
}

#[allow(dead_code)]
impl MemoryPoolManager {
    /// Get the singleton instance of MemoryPoolManager.
    pub fn instance(buffer_size: usize, pool_size: usize) -> Arc<Self> {
        use std::sync::OnceLock;
        static INSTANCE: OnceLock<Arc<MemoryPoolManager>> = OnceLock::new();

        INSTANCE
            .get_or_init(|| {
                let available_buffers = (0..pool_size).map(|_| vec![0u8; buffer_size]).collect();

                Arc::new(Self {
                    buffer_size,
                    pool_size,
                    available_buffers: Mutex::new(available_buffers),
                    total_buffers: Mutex::new(pool_size),
                })
            })
            .clone()
    }

    /// Acquire a buffer from the pool.
    /// If pool is exhausted, allocates a new buffer dynamically.
    pub fn acquire_buffer(&self) -> Vec<u8> {
        let mut buffers = self.available_buffers.lock().unwrap();

        if let Some(buffer) = buffers.pop() {
            println!("Acquired buffer from pool ({} remaining)", buffers.len());
            buffer
        } else {
            drop(buffers);
            // Pool exhausted, allocate new buffer
            let mut total = self.total_buffers.lock().unwrap();
            *total += 1;
            println!("Pool exhausted, allocated new buffer (total: {})", *total);
            vec![0u8; self.buffer_size]
        }
    }

    /// Release a buffer back to the pool.
    pub fn release_buffer(&self, mut buffer: Vec<u8>) {
        if buffer.len() != self.buffer_size {
            println!(
                "Warning: Buffer size mismatch: expected {}, got {}",
                self.buffer_size,
                buffer.len()
            );
            return;
        }

        let mut buffers = self.available_buffers.lock().unwrap();

        // Only return to pool if we haven't exceeded pool size
        if buffers.len() < self.pool_size {
            // Clear buffer before returning to pool
            buffer.fill(0);
            buffers.push(buffer);
        }

        println!("Released buffer to pool ({} available)", buffers.len());
    }

    /// Get the number of available buffers in the pool.
    pub fn get_available_buffers(&self) -> usize {
        self.available_buffers.lock().unwrap().len()
    }

    /// Get the total number of buffers (available + in-use).
    pub fn get_total_buffers(&self) -> usize {
        *self.total_buffers.lock().unwrap()
    }

    /// Get the buffer size.
    pub fn get_buffer_size(&self) -> usize {
        self.buffer_size
    }
}
