use super::file_manager;
use crate::logger;
use anyhow::Result;

pub struct VerificationResult {
    pub passed: bool,
    pub original_size: u64,
    pub downloaded_size: u64,
    pub original_checksum: String,
    pub downloaded_checksum: String,
}

pub async fn verify(original_path: &str, downloaded_path: &str) -> Result<VerificationResult> {
    logger::log_info(&format!("Original file: {}", original_path));
    logger::log_info(&format!("Downloaded file: {}", downloaded_path));

    // Get file sizes
    let original_size = file_manager::get_file_size(original_path)?;
    let downloaded_size = file_manager::get_file_size(downloaded_path)?;

    logger::log_info(&format!("Original size: {} bytes", original_size));
    logger::log_info(&format!("Downloaded size: {} bytes", downloaded_size));

    // Compute checksums
    let original_checksum = file_manager::compute_sha256(original_path).await?;
    let downloaded_checksum = file_manager::compute_sha256(downloaded_path).await?;

    logger::log_info(&format!(
        "Original checksum (SHA-256): {}",
        original_checksum
    ));
    logger::log_info(&format!(
        "Downloaded checksum (SHA-256): {}",
        downloaded_checksum
    ));

    // Compare
    let passed = original_size == downloaded_size
        && original_checksum.to_lowercase() == downloaded_checksum.to_lowercase();

    Ok(VerificationResult {
        passed,
        original_size,
        downloaded_size,
        original_checksum,
        downloaded_checksum,
    })
}
