use std::sync::{Arc, Mutex};

use anyhow::Result;
use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpStream;
use tokio_tungstenite::tungstenite::protocol::Message as WsMessage;
use tokio_tungstenite::WebSocketStream;

use super::message::{self, Message};
use super::protocol::{CommandType, DataCommand, QueryCommand, StreamCommand};
use super::stream_manager::StreamManager;

type WsSink = futures_util::stream::SplitSink<WebSocketStream<TcpStream>, WsMessage>;

/// Per-connection handler. Owns the connection identity and active stream ID.
pub struct Handler {
    mgr: Arc<Mutex<StreamManager>>,
    pub conn_id: String,
    pub stream_id: Option<String>,
}

impl Handler {
    pub fn new(mgr: Arc<Mutex<StreamManager>>, conn_id: String) -> Self {
        Self {
            mgr,
            conn_id,
            stream_id: None,
        }
    }

    /// Process one text frame.
    pub async fn handle_text(&mut self, text: &str, sink: &mut WsSink) -> Result<()> {
        match message::parse_command(text) {
            Ok((msg, info)) => match info.cmd_type {
                CommandType::Stream => {
                    self.handle_stream_cmd(info.stream_cmd.unwrap(), &msg, sink)
                        .await
                }
                CommandType::Data => {
                    self.handle_data_cmd(info.data_cmd.unwrap(), &msg, sink)
                        .await
                }
                CommandType::Query => {
                    self.handle_query_cmd(info.query_cmd.unwrap(), &msg, sink)
                        .await
                }
            },
            Err(e) => self.send_error(&e.to_string(), sink).await,
        }
    }

    /// Process one binary frame (upload data).
    pub async fn handle_binary(&mut self, data: &[u8], sink: &mut WsSink) -> Result<()> {
        let result = match &self.stream_id.clone() {
            Some(id) => self.mgr.lock().unwrap().write(id, data),
            None => Err(anyhow::anyhow!("No active upload stream")),
        };
        if let Err(e) = result {
            self.send_error(&e.to_string(), sink).await?;
        }
        Ok(())
    }

    /// Called on disconnect — marks active uploading stream as ERROR.
    pub fn on_close(&self) {
        if let Some(ref id) = self.stream_id {
            self.mgr.lock().unwrap().mark_error(id);
        }
    }

    // -- Stream commands --

    async fn handle_stream_cmd(
        &mut self,
        cmd: StreamCommand,
        msg: &Message,
        sink: &mut WsSink,
    ) -> Result<()> {
        let response: std::result::Result<Message, String> = match cmd {
            StreamCommand::Create => {
                let id = msg.stream_id.as_deref().unwrap_or("");
                if id.is_empty() {
                    Err("CREATE requires streamId".to_string())
                } else {
                    let id = id.to_string();
                    match self.mgr.lock().unwrap().create(&id) {
                        Ok(()) => {
                            self.stream_id = Some(id.clone());
                            Ok(message::created(&id))
                        }
                        Err(e) => Err(e.to_string()),
                    }
                }
            }
            StreamCommand::Complete => match self.stream_id.clone() {
                None => Err("No active stream".to_string()),
                Some(id) => match self.mgr.lock().unwrap().complete(&id) {
                    Ok(()) => {
                        self.stream_id = None;
                        Ok(message::completed(&id))
                    }
                    Err(e) => Err(e.to_string()),
                },
            },
            StreamCommand::Close => {
                let id = msg.stream_id.as_deref().unwrap_or("");
                if id.is_empty() {
                    Err("CLOSE requires streamId".to_string())
                } else {
                    let id = id.to_string();
                    match self.mgr.lock().unwrap().delete(&id) {
                        Ok(()) => Ok(message::closed(&id)),
                        Err(e) => Err(e.to_string()),
                    }
                }
            }
        };
        match response {
            Ok(m) => self.send(&m, sink).await,
            Err(e) => self.send_error(&e, sink).await,
        }
    }

    // -- Data commands --

    async fn handle_data_cmd(
        &mut self,
        _cmd: DataCommand,
        msg: &Message,
        sink: &mut WsSink,
    ) -> Result<()> {
        let id = msg.stream_id.as_deref().unwrap_or("");
        if id.is_empty() {
            return self.send_error("READ requires streamId", sink).await;
        }
        let offset = msg.offset.unwrap_or(0);
        let length = msg.length.unwrap_or(65536);

        let result = self.mgr.lock().unwrap().read(id, offset, length);
        match result {
            Ok(data) if !data.is_empty() => {
                sink.send(WsMessage::Binary(data.into())).await?;
            }
            Ok(_) => {
                self.send_error("No data at requested offset", sink).await?;
            }
            Err(e) => {
                self.send_error(&e.to_string(), sink).await?;
            }
        }
        Ok(())
    }

    // -- Query commands --

    async fn handle_query_cmd(
        &mut self,
        cmd: QueryCommand,
        msg: &Message,
        sink: &mut WsSink,
    ) -> Result<()> {
        let response: std::result::Result<Message, String> = match cmd {
            QueryCommand::GetStatus => {
                let id = msg.stream_id.as_deref().unwrap_or("");
                if id.is_empty() {
                    Err("GET_STATUS requires streamId".to_string())
                } else {
                    match self.mgr.lock().unwrap().status_of(id) {
                        Ok((st, size)) => Ok(message::status(id, &st.to_string(), size)),
                        Err(e) => Err(e.to_string()),
                    }
                }
            }
            QueryCommand::ListStreams => {
                let ids = self.mgr.lock().unwrap().list();
                Ok(message::stream_list(&ids))
            }
        };
        match response {
            Ok(m) => self.send(&m, sink).await,
            Err(e) => self.send_error(&e, sink).await,
        }
    }

    // -- Helpers --

    async fn send(&self, msg: &Message, sink: &mut WsSink) -> Result<()> {
        let json = serde_json::to_string(msg)?;
        sink.send(WsMessage::Text(json.into())).await?;
        Ok(())
    }

    async fn send_error(&self, msg: &str, sink: &mut WsSink) -> Result<()> {
        eprintln!("[{}] error: {}", self.conn_id, msg);
        let m = message::error(msg);
        let json = serde_json::to_string(&m)?;
        sink.send(WsMessage::Text(json.into())).await?;
        Ok(())
    }
}

/// Drive the per-connection read loop.
pub async fn serve_connection(
    ws_stream: WebSocketStream<TcpStream>,
    mgr: Arc<Mutex<StreamManager>>,
    conn_id: String,
) {
    let (mut sink, mut stream) = ws_stream.split();

    // Send CONNECTED
    {
        let connected = message::connected(&conn_id);
        if let Ok(json) = serde_json::to_string(&connected) {
            let _ = sink.send(WsMessage::Text(json.into())).await;
        }
    }

    let mut handler = Handler::new(mgr, conn_id.clone());

    while let Some(result) = stream.next().await {
        match result {
            Ok(WsMessage::Text(text)) => {
                if let Err(e) = handler.handle_text(&text, &mut sink).await {
                    eprintln!("[{}] text error: {}", conn_id, e);
                    break;
                }
            }
            Ok(WsMessage::Binary(data)) => {
                if let Err(e) = handler.handle_binary(&data, &mut sink).await {
                    eprintln!("[{}] binary error: {}", conn_id, e);
                    break;
                }
            }
            Ok(WsMessage::Close(_)) | Err(_) => break,
            _ => {}
        }
    }

    handler.on_close();
    eprintln!("[{}] disconnected", conn_id);
}
