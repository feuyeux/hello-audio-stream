// Audio stream server module
pub mod handler;
pub mod memory;
pub mod network;

use crate::server::memory::MemoryPoolManager;
use crate::server::memory::StreamManager;
use crate::server::network::AudioWebSocketServer;
use crate::logger;

pub async fn run(port: u16, path: &str) -> anyhow::Result<()> {
    logger::log_info("Starting Audio Server Application...");
    logger::log_info(&format!("Port: {}, Endpoint: {}", port, path));
    logger::log_info("Press Ctrl+C to stop");

    let stream_manager = StreamManager::instance("cache".to_string());
    let memory_pool = MemoryPoolManager::instance(64 * 1024, 16);
    stream_manager.cleanup_old_streams(24);

    logger::log_info("StreamManager: cache directory = cache");
    logger::log_info(&format!(
        "Active streams after startup cleanup: {}",
        stream_manager.list_active_streams().len()
    ));
    logger::log_info(&format!("MemoryPool: {} buffers × {} bytes",
        memory_pool.get_total_buffers(), memory_pool.get_buffer_size()));
    logger::log_info(&format!(
        "MemoryPool available buffers: {}",
        memory_pool.get_available_buffers()
    ));

    let ws_server = AudioWebSocketServer::new(
        port,
        stream_manager,
        memory_pool,
    );

    logger::log_info(&format!("AudioWebSocketServer initialized on 0.0.0.0:{}{}", port, path));

    // Start server (blocking)
    ws_server.start();

    tokio::signal::ctrl_c().await?;

    logger::log_info("Server stopped");
    Ok(())
}
