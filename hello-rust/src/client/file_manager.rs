use anyhow::{Context, Result};
use sha2::{Digest, Sha256};
use std::path::Path;
use tokio::fs::{File, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};

pub const CHUNK_SIZE: usize = 65536; // 64KB

pub async fn read_chunk(path: &str, offset: u64, size: usize) -> Result<Vec<u8>> {
    let mut file = File::open(path)
        .await
        .context(format!("Failed to open file: {}", path))?;

    file.seek(std::io::SeekFrom::Start(offset))
        .await
        .context("Failed to seek file")?;

    let mut buffer = vec![0u8; size];
    let bytes_read = file
        .read(&mut buffer)
        .await
        .context("Failed to read file")?;
    buffer.truncate(bytes_read);

    Ok(buffer)
}

pub async fn write_chunk(path: &str, data: &[u8], append: bool) -> Result<()> {
    // Ensure parent directory exists
    if let Some(parent) = Path::new(path).parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .context("Failed to create output directory")?;
    }

    let mut file = if append {
        OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .await
            .context(format!("Failed to open file for writing: {}", path))?
    } else {
        File::create(path)
            .await
            .context(format!("Failed to create file: {}", path))?
    };

    file.write_all(data)
        .await
        .context("Failed to write to file")?;

    Ok(())
}

#[allow(dead_code)]
pub async fn read_file(path: &str) -> Result<Vec<u8>> {
    tokio::fs::read(path)
        .await
        .context(format!("Failed to read file: {}", path))
}

#[allow(dead_code)]
pub async fn write_file(path: &str, data: &[u8]) -> Result<()> {
    // Ensure parent directory exists
    if let Some(parent) = Path::new(path).parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .context("Failed to create output directory")?;
    }

    tokio::fs::write(path, data)
        .await
        .context(format!("Failed to write file: {}", path))
}

pub async fn compute_sha256(path: &str) -> Result<String> {
    let mut file = File::open(path)
        .await
        .context(format!("Failed to open file for checksum: {}", path))?;

    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; CHUNK_SIZE];

    loop {
        let bytes_read = file
            .read(&mut buffer)
            .await
            .context("Failed to read file")?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    let result = hasher.finalize();
    Ok(format!("{:x}", result))
}

pub fn get_file_size(path: &str) -> Result<u64> {
    let metadata =
        std::fs::metadata(path).context(format!("Failed to get file metadata: {}", path))?;
    Ok(metadata.len())
}
