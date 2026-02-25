use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicU64, Ordering};

use anyhow::Result;
use tokio::net::TcpListener;
use tokio_tungstenite::accept_async;

use super::handler::serve_connection;
use super::stream_manager::{Config, StreamManager};

/// WebSocket server for audio streaming.
pub struct Server {
    port: u16,
    path: String,
    mgr: Arc<Mutex<StreamManager>>,
}

impl Server {
    pub fn new(port: u16, path: &str, cache_dir: PathBuf) -> Self {
        let config = Config::new(cache_dir);
        Self {
            port,
            path: path.to_string(),
            mgr: Arc::new(Mutex::new(StreamManager::new(config))),
        }
    }

    pub async fn run(&self) -> Result<()> {
        let addr = format!("0.0.0.0:{}", self.port);
        let listener = TcpListener::bind(&addr).await?;
        println!("Server listening on ws://{}{}", addr, self.path);

        // Cleanup ticker — every 30 seconds
        let mgr_cleanup = self.mgr.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(std::time::Duration::from_secs(30));
            loop {
                interval.tick().await;
                mgr_cleanup.lock().unwrap().cleanup();
            }
        });

        static CONN_SEQ: AtomicU64 = AtomicU64::new(0);

        loop {
            let (tcp_stream, peer) = listener.accept().await?;
            let ws_stream = match accept_async(tcp_stream).await {
                Ok(ws) => ws,
                Err(e) => {
                    eprintln!("WebSocket handshake failed from {:?}: {}", peer, e);
                    continue;
                }
            };
            let seq = CONN_SEQ.fetch_add(1, Ordering::Relaxed);
            let conn_id = format!("c-{}", seq);
            let mgr = self.mgr.clone();
            tokio::spawn(serve_connection(ws_stream, mgr, conn_id));
        }
    }
}

/// Entry point called from `src/bin/server.rs`.
pub async fn run(port: u16, path: &str, cache_dir: &str) -> Result<()> {
    let server = Server::new(port, path, PathBuf::from(cache_dir));
    server.run().await
}
