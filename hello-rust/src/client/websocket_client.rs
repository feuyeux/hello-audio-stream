use anyhow::{Context, Result};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::Message, MaybeTlsStream, WebSocketStream};
use tungstenite::{Bytes, Utf8Bytes};

type WsStream = WebSocketStream<MaybeTlsStream<TcpStream>>;

#[derive(Serialize, Deserialize, Debug)]
pub struct ControlMessage {
    #[serde(rename = "type")]
    pub msg_type: String,
    #[serde(rename = "streamId")]
    pub stream_id: Option<String>,
    #[serde(rename = "offset")]
    pub offset: Option<u64>,
    #[serde(rename = "length")]
    pub length: Option<usize>,
    #[serde(rename = "message")]
    pub message: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct StreamMessage {
    #[serde(rename = "type")]
    pub msg_type: String,
    #[serde(rename = "streamId")]
    pub stream_id: Option<String>,
    #[serde(rename = "offset")]
    pub offset: Option<u64>,
    #[serde(rename = "length")]
    pub length: Option<usize>,
    #[serde(rename = "message")]
    pub message: Option<String>,
}

pub struct WebSocketClient {
    stream: Option<WsStream>,
}

impl WebSocketClient {
    pub fn new(_uri: &str) -> Self {
        Self {
            stream: None,
        }
    }

    pub async fn connect(&mut self, uri: &str) -> Result<()> {
        let (stream, _) = connect_async(uri)
            .await
            .context(format!("Failed to connect to WebSocket server: {}", uri))?;

        self.stream = Some(stream);
        Ok(())
    }

    pub async fn send_text(&mut self, message: &str) -> Result<()> {
        let stream = self.stream.as_mut().context("Not connected")?;
        stream
            .send(Message::Text(Utf8Bytes::from(message)))
            .await
            .context("Failed to send text message")?;
        Ok(())
    }

    pub async fn send_binary(&mut self, data: Vec<u8>) -> Result<()> {
        let stream = self.stream.as_mut().context("Not connected")?;
        stream
            .send(Message::Binary(Bytes::from(data)))
            .await
            .context("Failed to send binary message")?;
        Ok(())
    }

    pub async fn receive(&mut self) -> Result<Option<Message>> {
        let stream = self.stream.as_mut().context("Not connected")?;
        let msg = stream.next().await;
        match msg {
            Some(result) => Ok(Some(result?)),
            None => Ok(None),
        }
    }

    pub async fn receive_text(&mut self) -> Result<String> {
        let msg = self.receive().await?;

        match msg {
            Some(Message::Text(text)) => Ok(text.to_string()),
            Some(Message::Close(_)) => Ok(String::new()),
            _ => anyhow::bail!("Expected text message, got {:?}", msg),
        }
    }

    pub async fn receive_binary(&mut self) -> Result<Vec<u8>> {
        let msg = self.receive().await?;

        match msg {
            Some(Message::Binary(data)) => Ok(data.to_vec()),
            Some(Message::Close(_)) => Ok(Vec::new()),
            _ => anyhow::bail!("Expected binary message, got {:?}", msg),
        }
    }

    pub async fn close(&mut self) -> Result<()> {
        if let Some(stream) = self.stream.as_mut() {
            stream.close(None)
                .await
                .context("Failed to close WebSocket connection")?;
        }
        Ok(())
    }

    pub async fn send_control_message(&mut self, msg: ControlMessage) -> Result<()> {
        let json = serde_json::to_string(&msg)
            .context("Failed to serialize control message")?;
        self.send_text(&json).await
    }

    pub async fn receive_control_message(&mut self) -> Result<ControlMessage> {
        let text = self.receive_text().await?;
        if text.is_empty() {
            anyhow::bail!("Connection closed");
        }
        serde_json::from_str(&text).context("Failed to parse control message")
    }
}
