use super::{download_manager, file_manager, upload_manager, websocket_client::WebSocketClient};
use super::{performance_monitor::PerformanceMonitor, verification_module};
use crate::cli;
use crate::logger;
use anyhow::Result;

pub async fn run_client() -> Result<()> {
    // Parse CLI arguments
    let config = cli::Config::parse();

    // Initialize logger
    logger::init(config.verbose);

    // Log startup information
    logger::log_info("Audio Stream Cache Client - Rust Implementation");
    logger::log_info(&format!("Server URI: {}", config.server));
    logger::log_info(&format!("Input file: {}", config.input));
    logger::log_info(&format!("Output file: {}", config.output));

    // Get input file size
    let file_size = file_manager::get_file_size(&config.input)?;
    logger::log_info(&format!("Input file size: {} bytes", file_size));

    // Initialize performance monitor
    let mut perf = PerformanceMonitor::new(file_size);

    // Connect to WebSocket server
    logger::log_phase("Connecting to Server");
    let mut ws_client = WebSocketClient::connect(&config.server).await?;
    logger::log_info("Successfully connected to server");

    // Upload file
    logger::log_phase("Starting Upload");
    perf.start_upload();
    let stream_id = upload_manager::upload(&mut ws_client, &config.input, file_size).await?;
    perf.end_upload();
    logger::log_info(&format!(
        "Upload completed successfully with stream ID: {}",
        stream_id
    ));

    // Sleep 2 seconds after upload
    logger::log_info("Upload successful, sleeping for 2 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Download file
    logger::log_phase("Starting Download");
    perf.start_download();
    download_manager::download(&mut ws_client, &stream_id, &config.output, file_size).await?;
    perf.end_download();
    logger::log_info("Download completed successfully");

    // Sleep 2 seconds after download
    logger::log_info("Download successful, sleeping for 2 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Verify file integrity
    logger::log_phase("Verifying File Integrity");
    let verification_result = verification_module::verify(&config.input, &config.output).await?;

    if verification_result.passed {
        logger::log_info("✓ File verification PASSED - Files are identical");
    } else {
        logger::log_error("✗ File verification FAILED");
        if verification_result.original_size != verification_result.downloaded_size {
            logger::log_error(&format!(
                "  Reason: File size mismatch (expected {}, got {})",
                verification_result.original_size, verification_result.downloaded_size
            ));
        }
        if verification_result.original_checksum != verification_result.downloaded_checksum {
            logger::log_error("  Reason: Checksum mismatch");
        }
        std::process::exit(1);
    }

    // Generate performance report
    logger::log_phase("Performance Report");
    let report = perf.get_report();
    logger::log_info(&format!(
        "Upload Duration: {} ms",
        report.upload_duration_ms
    ));
    logger::log_info(&format!(
        "Upload Throughput: {:.2} Mbps",
        report.upload_throughput_mbps
    ));
    logger::log_info(&format!(
        "Download Duration: {} ms",
        report.download_duration_ms
    ));
    logger::log_info(&format!(
        "Download Throughput: {:.2} Mbps",
        report.download_throughput_mbps
    ));
    logger::log_info(&format!("Total Duration: {} ms", report.total_duration_ms));
    logger::log_info(&format!(
        "Average Throughput: {:.2} Mbps",
        report.average_throughput_mbps
    ));

    // Check performance targets
    if report.upload_throughput_mbps < 100.0 || report.download_throughput_mbps < 200.0 {
        logger::log_warn("⚠ Performance targets not met (Upload >100 Mbps, Download >200 Mbps)");
    }

    // Disconnect
    ws_client.close().await?;
    logger::log_info("Disconnected from server");

    // Log completion
    logger::log_phase("Workflow Complete");
    logger::log_info(&format!(
        "Successfully uploaded, downloaded, and verified file: {}",
        config.input
    ));

    Ok(())
}
