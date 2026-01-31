pub mod chunk_manager;
pub mod download_manager;
pub mod file_manager;
pub mod performance_monitor;
pub mod stream_id_generator;
pub mod upload_manager;
pub mod verification_module;
pub mod websocket_client;

use super::cli::Config;
use super::logger;
use anyhow::Result;

pub async fn run(config: &Config) -> Result<()> {
    logger::log_info("========================================");
    logger::log_info("Starting Audio Stream Test");
    logger::log_info("========================================");
    logger::log_info(&format!("Input File: {}", config.input));
    logger::log_info(&format!("Output File: {}", config.output));
    logger::log_info("========================================");

    // Validate input file
    let file_size = file_manager::get_file_size(&config.input)
        .map_err(|e| anyhow::anyhow!("Failed to get file size: {}", e))?;

    logger::log_info(&format!("Input file size: {} bytes", file_size));

    // Initialize components
    let mut ws_client = websocket_client::WebSocketClient::new(&config.server);
    
    // Connect to server
    logger::log_info("========================================");
    logger::log_info("Connecting to Server");
    logger::log_info("========================================");
    
    ws_client.connect(&config.server).await
        .map_err(|e| anyhow::anyhow!("Failed to connect to server: {}", e))?;
    
    logger::log_info("Successfully connected to server");

    // Phase 1: Upload
    logger::log_info("========================================");
    logger::log_info("[1/3] Uploading file...");
    logger::log_info("========================================");
    
    let upload_start = std::time::Instant::now();
    let stream_id = upload_manager::upload(&mut ws_client, &config.input, file_size).await
        .map_err(|e| anyhow::anyhow!("Upload failed: {}", e))?;
    
    let upload_duration = upload_start.elapsed().as_millis() as f64;
    let upload_throughput = (file_size as f64 * 8.0) / (upload_duration * 1_000_000.0);
    
    logger::log_info(&format!("Upload result: streamId={}, duration={}ms, throughput={} Mbps",
        stream_id, upload_duration as u64, upload_throughput));

    logger::log_info("Upload successful, sleeping for 2 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Phase 2: Download
    logger::log_info("========================================");
    logger::log_info("[2/3] Downloading file...");
    logger::log_info("========================================");
    
    let download_start = std::time::Instant::now();
    let downloaded_size = download_manager::download(&mut ws_client, &stream_id, &config.output, file_size).await
        .map_err(|e| anyhow::anyhow!("Download failed: {}", e))?;
    
    let download_duration = download_start.elapsed().as_millis() as f64;
    let download_throughput = (downloaded_size as f64 * 8.0) / (download_duration * 1_000_000.0);

    logger::log_info(&format!("Download result: success={}, duration={}ms, throughput={} Mbps",
        true, download_duration as u64, download_throughput));

    logger::log_info("Download successful, sleeping for 2 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Phase 3: Verification
    logger::log_info("========================================");
    logger::log_info("[3/3] Comparing files...");
    logger::log_info("========================================");
    
    let verification_result = verification_module::verify(&config.input, &config.output).await
        .map_err(|e| anyhow::anyhow!("Verification failed: {}", e))?;

    // Performance report
    logger::log_info("========================================");
    logger::log_info("Operation Summary");
    logger::log_info("========================================");
    logger::log_info(&format!("Stream ID: {}", stream_id));
    logger::log_info(&format!("Total Duration: {} ms", upload_duration as u64 + download_duration as u64));
    logger::log_info(&format!("Upload Time: {} ms", upload_duration as u64));
    logger::log_info(&format!("Download Time: {} ms", download_duration as u64));
    logger::log_info(&format!("Upload Throughput: {} Mbps", upload_throughput));
    logger::log_info(&format!("Download Throughput: {} Mbps", download_throughput));
    logger::log_info(&format!("Content Match: {}", verification_result.passed));
    logger::log_info(&format!("Overall Result: {}",
        if verification_result.passed { "SUCCESS" } else { "FAILED" }));

    logger::log_info("========================================");
    logger::log_info("Audio stream test completed successfully!");
    logger::log_info("========================================");

    // Disconnect from server
    let _ = ws_client.close().await;
    logger::log_info("Disconnected from server");

    Ok(())
}
