// Main entry point for Rust audio stream server.

use crate::server::memory::{MemoryPoolManager, StreamManager};
use crate::server::network::AudioWebSocketServer;
use std::env;

#[allow(dead_code)]
pub fn run_server() {
    // Parse command-line arguments
    let args: Vec<String> = env::args().collect();
    let mut port = 8080;
    let mut path = "/audio".to_string();

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--port" => {
                if i + 1 < args.len() {
                    port = args[i + 1].parse().unwrap_or(8080);
                    i += 1;
                }
            }
            "--path" => {
                if i + 1 < args.len() {
                    path = args[i + 1].clone();
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }

    println!("Starting Audio Server on port {} with path {}", port, path);

    // Get singleton instances
    let stream_manager = StreamManager::instance("cache".to_string());
    let memory_pool = MemoryPoolManager::instance(65536, 100);

    // Create and start WebSocket server
    let ws_server = AudioWebSocketServer::new(port, path, stream_manager, memory_pool);

    ws_server.start();
}
