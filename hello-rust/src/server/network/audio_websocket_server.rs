// WebSocket server for audio streaming.
// Handles client connections and message routing.
// Matches Python WebSocketServer and Java AudioWebSocketServer functionality.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::server::handler::WebSocketMessageHandler;
use crate::server::memory::{MemoryPoolManager, StreamManager};

/// WebSocket server for handling audio stream uploads and downloads.
#[allow(dead_code)]
pub struct AudioWebSocketServer {
    port: u16,
    path: String,
    clients: Arc<Mutex<HashMap<usize, String>>>, // Maps client to stream ID
    stream_manager: Arc<StreamManager>,
    memory_pool: Arc<MemoryPoolManager>,
}

impl AudioWebSocketServer {
    /// Create a new WebSocket server.
    pub fn new(
        port: u16,
        path: String,
        stream_manager: Arc<StreamManager>,
        memory_pool: Arc<MemoryPoolManager>,
    ) -> Self {
        Self {
            port,
            path,
            clients: Arc::new(Mutex::new(HashMap::new())),
            stream_manager,
            memory_pool,
        }
    }

    /// Start the WebSocket server.
    pub fn start(&self) {
        use tungstenite::protocol::Message;

        let addr = format!("0.0.0.0:{}", self.port);
        let listener = std::net::TcpListener::bind(&addr).expect("Failed to bind to address");
        println!("WebSocket server started on ws://{}", addr);

        for stream in listener.incoming() {
            match stream {
                Ok(stream) => {
                    let addr = stream.peer_addr().ok();
                    let clients = self.clients.clone();
                    let stream_mgr = self.stream_manager.clone();
                    let mem_pool = self.memory_pool.clone();
                    let _path = self.path.clone();

                    std::thread::spawn(move || {
                        let mut websocket = tungstenite::accept(stream).unwrap();

                        // Generate client ID
                        let client_id = std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .unwrap()
                            .as_nanos() as usize;
                        clients.lock().unwrap().insert(client_id, String::new());

                        println!("Client connected: {:?}", addr);

                        // Handle messages
                        loop {
                            match websocket.read() {
                                Ok(msg) => match msg {
                                    Message::Text(text) => {
                                        WebSocketMessageHandler::handle_text_message(
                                            &mut websocket,
                                            &clients,
                                            &stream_mgr,
                                            &mem_pool,
                                            client_id,
                                            &text,
                                        );
                                    }
                                    Message::Binary(data) => {
                                        WebSocketMessageHandler::handle_binary_message(
                                            &clients,
                                            &stream_mgr,
                                            client_id,
                                            &data,
                                        );
                                    }
                                    Message::Close(_) => {
                                        println!("Client disconnected: {:?}", addr);
                                        clients.lock().unwrap().remove(&client_id);
                                        break;
                                    }
                                    _ => {}
                                },
                                Err(e) => {
                                    println!("Error reading message: {:?}", e);
                                    clients.lock().unwrap().remove(&client_id);
                                    break;
                                }
                            }
                        }
                    });
                }
                Err(e) => {
                    eprintln!("Error accepting connection: {:?}", e);
                }
            }
        }
    }
}
