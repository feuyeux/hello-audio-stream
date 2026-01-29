// WebSocket message handler for processing client messages.
// Handles START, STOP, and GET message types.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::server::memory::{MemoryPoolManager, StreamManager};
use tungstenite::protocol::Message as WsMessage;
use tungstenite::{Bytes, Utf8Bytes, WebSocket};

/// WebSocket message types
#[derive(Debug, Serialize, Deserialize)]
pub struct ControlMessage {
    #[serde(rename = "type")]
    pub msg_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub offset: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub length: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

pub struct WebSocketMessageHandler;

impl WebSocketMessageHandler {
    /// Handle a text (JSON) control message.
    pub fn handle_text_message(
        websocket: &mut WebSocket<std::net::TcpStream>,
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        stream_mgr: &Arc<StreamManager>,
        _mem_pool: &Arc<MemoryPoolManager>,
        client_id: usize,
        message: &str,
    ) {
        let data: Value = match serde_json::from_str(message) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("Invalid JSON message: {:?}", e);
                Self::send_error(websocket, clients, client_id, "Invalid JSON format");
                return;
            }
        };

        let msg_type = data["type"].as_str().unwrap_or("");

        match msg_type {
            "START" => Self::handle_start(websocket, clients, stream_mgr, client_id, &data),
            "STOP" => Self::handle_stop(websocket, clients, stream_mgr, client_id, &data),
            "GET" => Self::handle_get(websocket, clients, stream_mgr, client_id, &data),
            _ => {
                eprintln!("Unknown message type: {}", msg_type);
                Self::send_error(
                    websocket,
                    clients,
                    client_id,
                    &format!("Unknown message type: {}", msg_type),
                );
            }
        }
    }

    /// Handle binary audio data.
    pub fn handle_binary_message(
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        stream_mgr: &Arc<StreamManager>,
        client_id: usize,
        data: &[u8],
    ) {
        // Get active stream ID for this client
        let stream_id = {
            let clients = clients.lock().unwrap();
            clients.get(&client_id).cloned()
        };

        if stream_id.is_none() || stream_id.as_ref().unwrap().is_empty() {
            println!("[ERROR] Received binary data but no active stream for client");
            return;
        }

        let stream_id = stream_id.unwrap();

        // Write to stream
        stream_mgr.write_chunk(&stream_id, data);
    }

    /// Handle START message (create new stream).
    fn handle_start(
        websocket: &mut WebSocket<std::net::TcpStream>,
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        stream_mgr: &Arc<StreamManager>,
        client_id: usize,
        data: &Value,
    ) {
        let stream_id = match data["streamId"].as_str() {
            Some(id) => id.to_string(),
            None => {
                Self::send_error(websocket, clients, client_id, "Missing streamId");
                return;
            }
        };

        // Create stream
        if stream_mgr.create_stream(stream_id.clone()) {
            // Register this client with the stream
            clients.lock().unwrap().insert(client_id, stream_id.clone());

            let response = ControlMessage {
                msg_type: "STARTED".to_string(), // Use uppercase to match client expectation
                stream_id: Some(stream_id.clone()),
                offset: None,
                length: None,
                message: Some("Stream created".to_string()),
            };

            Self::send_json(websocket, clients, client_id, &response);
            println!("Stream started: {}", stream_id);
        } else {
            Self::send_error(
                websocket,
                clients,
                client_id,
                &format!("Failed to create stream: {}", stream_id),
            );
        }
    }

    /// Handle STOP message (finalize stream).
    fn handle_stop(
        websocket: &mut WebSocket<std::net::TcpStream>,
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        stream_mgr: &Arc<StreamManager>,
        client_id: usize,
        data: &Value,
    ) {
        let stream_id = match data["streamId"].as_str() {
            Some(id) => id.to_string(),
            None => {
                Self::send_error(websocket, clients, client_id, "Missing streamId");
                return;
            }
        };

        // Finalize stream
        if stream_mgr.finalize_stream(&stream_id) {
            let response = ControlMessage {
                msg_type: "STOPPED".to_string(), // Use uppercase to match client expectation
                stream_id: Some(stream_id.clone()),
                offset: None,
                length: None,
                message: Some("Stream finalized".to_string()),
            };

            Self::send_json(websocket, clients, client_id, &response);
            println!("Stream finalized: {}", stream_id);

            // Unregister stream from client
            clients.lock().unwrap().insert(client_id, String::new());
        } else {
            Self::send_error(
                websocket,
                clients,
                client_id,
                &format!("Failed to finalize stream: {}", stream_id),
            );
        }
    }

    /// Handle GET message (read stream data).
    fn handle_get(
        websocket: &mut WebSocket<std::net::TcpStream>,
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        stream_mgr: &Arc<StreamManager>,
        client_id: usize,
        data: &Value,
    ) {
        let stream_id = match data["streamId"].as_str() {
            Some(id) => id.to_string(),
            None => {
                Self::send_error(websocket, clients, client_id, "Missing streamId");
                return;
            }
        };

        let offset = data["offset"].as_u64().unwrap_or(0);
        let length = data["length"].as_u64().unwrap_or(65536) as usize;

        // Read data from stream
        let chunk_data = stream_mgr.read_chunk(&stream_id, offset, length);

        if !chunk_data.is_empty() {
            // Send binary data via WebSocket
            match websocket.send(WsMessage::Binary(Bytes::from(chunk_data))) {
                Ok(_) => {
                    println!(
                        "Sent {} bytes for stream {} at offset {}",
                        length, stream_id, offset
                    );
                }
                Err(e) => {
                    eprintln!("Failed to send binary data: {:?}", e);
                }
            }
        } else {
            Self::send_error(
                websocket,
                clients,
                client_id,
                &format!("Failed to read from stream: {}", stream_id),
            );
        }
    }

    /// Send a JSON message to the client.
    fn send_json(
        websocket: &mut WebSocket<std::net::TcpStream>,
        _clients: &Arc<Mutex<HashMap<usize, String>>>,
        client_id: usize,
        data: &ControlMessage,
    ) {
        let json = match serde_json::to_string(data) {
            Ok(j) => j,
            Err(e) => {
                eprintln!("Error marshaling JSON: {:?}", e);
                return;
            }
        };

        // Send via WebSocket
        match websocket.send(WsMessage::Text(Utf8Bytes::from(json.as_str()))) {
            Ok(_) => {
                println!("Sending to client {}: {}", client_id, json);
            }
            Err(e) => {
                eprintln!("Failed to send message to client: {:?}", e);
            }
        }
    }

    /// Send an error message to the client.
    fn send_error(
        websocket: &mut WebSocket<std::net::TcpStream>,
        clients: &Arc<Mutex<HashMap<usize, String>>>,
        client_id: usize,
        message: &str,
    ) {
        let response = ControlMessage {
            msg_type: "ERROR".to_string(),
            stream_id: None,
            offset: None,
            length: None,
            message: Some(message.to_string()),
        };

        Self::send_json(websocket, clients, client_id, &response);
        eprintln!("Sent error to client: {}", message);
    }
}
