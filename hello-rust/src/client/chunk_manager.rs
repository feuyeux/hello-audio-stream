// Chunk manager for handling file chunking operations

#[allow(dead_code)]
pub const CHUNK_SIZE: usize = 65536; // 64KB

#[allow(dead_code)]
pub struct ChunkManager;

#[allow(dead_code)]
impl ChunkManager {
    pub fn calculate_chunk_count(file_size: u64, chunk_size: usize) -> usize {
        ((file_size + chunk_size as u64 - 1) / chunk_size as u64) as usize
    }

    pub fn get_chunk_size(file_size: u64, offset: u64, default_chunk_size: usize) -> usize {
        std::cmp::min(default_chunk_size as u64, file_size - offset) as usize
    }
}
