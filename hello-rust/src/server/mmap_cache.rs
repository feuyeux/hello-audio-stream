use anyhow::Result;
use memmap2::MmapMut;
use std::fs::{File, OpenOptions};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

const MAX_CACHE_SIZE: u64 = 8 * 1024 * 1024 * 1024; // 8 GB

/// Memory-mapped file cache for a single audio stream.
pub struct MmapCache {
    path: PathBuf,
    file: Mutex<Option<File>>,
    mmap: Mutex<Option<MmapMut>>,
    size: Mutex<u64>,
    active: Mutex<bool>,
}

impl MmapCache {
    pub fn new(path: PathBuf) -> Self {
        Self {
            path,
            file: Mutex::new(None),
            mmap: Mutex::new(None),
            size: Mutex::new(0),
            active: Mutex::new(false),
        }
    }

    /// Create (or truncate) the backing file and map it.
    pub fn create(&self, initial_size: u64) -> Result<()> {
        if Path::new(&self.path).exists() {
            std::fs::remove_file(&self.path)?;
        }

        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .open(&self.path)?;

        if initial_size > 0 {
            file.set_len(initial_size)?;
        }

        *self.size.lock().unwrap() = initial_size;
        *self.file.lock().unwrap() = Some(file);

        if initial_size > 0 {
            self.map_file()?;
        }

        *self.active.lock().unwrap() = true;
        Ok(())
    }

    /// Write data at the given offset, growing the file if necessary.
    pub fn write(&self, offset: u64, data: &[u8]) -> usize {
        if !*self.active.lock().unwrap() {
            if self.create(offset + data.len() as u64).is_err() {
                return 0;
            }
        }

        let required = offset + data.len() as u64;
        let current = *self.size.lock().unwrap();
        let mapped = self.mmap.lock().unwrap().is_some();

        if required > current || !mapped {
            let new_size = required.max(current);
            if self.resize(new_size).is_err() {
                return 0;
            }
        }

        let mut mmap_lock = self.mmap.lock().unwrap();
        if let Some(ref mut mmap) = *mmap_lock {
            let off = offset as usize;
            if off + data.len() <= mmap.len() {
                mmap[off..off + data.len()].copy_from_slice(data);
                return data.len();
            }
        }
        0
    }

    /// Read up to `length` bytes starting at `offset`.
    pub fn read(&self, offset: u64, length: usize) -> Vec<u8> {
        let active = *self.active.lock().unwrap();
        let has_mmap = self.mmap.lock().unwrap().is_some();

        if !active || !has_mmap {
            if let Err(e) = self.open() {
                eprintln!("MmapCache open failed: {}", e);
                return vec![];
            }
        }

        let size = *self.size.lock().unwrap();
        if offset >= size {
            return vec![];
        }
        let actual = length.min((size - offset) as usize);

        let mmap_lock = self.mmap.lock().unwrap();
        if let Some(ref mmap) = *mmap_lock {
            let off = offset as usize;
            if off + actual <= mmap.len() {
                return mmap[off..off + actual].to_vec();
            }
        }
        vec![]
    }

    /// Truncate the file to its final size and flush.
    pub fn finalize(&self, final_size: u64) -> Result<()> {
        self.resize(final_size)?;
        let mmap_lock = self.mmap.lock().unwrap();
        if let Some(ref mmap) = *mmap_lock {
            mmap.flush()?;
        }
        Ok(())
    }

    /// Unmap and close the backing file.
    pub fn close(&self) {
        *self.mmap.lock().unwrap() = None;
        *self.file.lock().unwrap() = None;
        *self.active.lock().unwrap() = false;
    }

    // ── Internal helpers ─────────────────────────────────────────────────

    fn open(&self) -> Result<()> {
        let file = OpenOptions::new().read(true).write(true).open(&self.path)?;
        let size = file.metadata()?.len();
        *self.size.lock().unwrap() = size;
        *self.file.lock().unwrap() = Some(file);
        if size > 0 {
            self.map_file()?;
        }
        *self.active.lock().unwrap() = true;
        Ok(())
    }

    fn map_file(&self) -> Result<()> {
        let file_lock = self.file.lock().unwrap();
        if let Some(ref file) = *file_lock {
            let mmap = unsafe { MmapMut::map_mut(file)? };
            *self.mmap.lock().unwrap() = Some(mmap);
        }
        Ok(())
    }

    fn resize(&self, new_size: u64) -> Result<()> {
        if new_size > MAX_CACHE_SIZE {
            return Err(anyhow::anyhow!("Exceeds max cache size: {}", new_size));
        }
        // Drop the mmap before resizing
        *self.mmap.lock().unwrap() = None;
        {
            let file_lock = self.file.lock().unwrap();
            if let Some(ref file) = *file_lock {
                file.set_len(new_size)?;
            }
        }
        *self.size.lock().unwrap() = new_size;
        if new_size > 0 {
            self.map_file()?;
        }
        Ok(())
    }
}
