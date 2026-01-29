use anyhow::{Context, Result};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::Message, MaybeTlsStream, WebSocketStream};
use tungstenite::{Bytes, Utf8Bytes};

type WsStream = WebSocketStream<MaybeTlsStream<TcpStream>>;

pub struct WebSocketClient {
    stream: WsStream,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ControlMessage {
    #[serde(rename = "type")]
    pub msg_type: String,
    #[serde(rename = "streamId")]
    pub stream_id: Option<String>,
    pub offset: Option<u64>,
    pub length: Option<usize>,
    pub message: Option<String>,
}

impl WebSocketClient {
    pub async fn connect(uri: &str) -> Result<Self> {
        let (stream, _) = connect_async(uri)
            .await
            .context(format!("Failed to connect to WebSocket server: {}", uri))?;

        Ok(Self { stream })
    }

    pub async fn send_text(&mut self, message: &str) -> Result<()> {
        self.stream
            .send(Message::Text(Utf8Bytes::from(message)))
            .await
            .context("Failed to send text message")?;
        Ok(())
    }

    pub async fn send_binary(&mut self, data: Vec<u8>) -> Result<()> {
        self.stream
            .send(Message::Binary(Bytes::from(data)))
            .await
            .context("Failed to send binary message")?;
        Ok(())
    }

    pub async fn receive(&mut self) -> Result<Message> {
        if let Some(msg) = self.stream.next().await {
            msg.context("Failed to receive message")
        } else {
            anyhow::bail!("WebSocket connection closed")
        }
    }

    pub async fn receive_text(&mut self) -> Result<String> {
        let msg = self.receive().await?;
        match msg {
            Message::Text(text) => Ok(text.to_string()),
            _ => anyhow::bail!("Expected text message, got {:?}", msg),
        }
    }

    pub async fn receive_binary(&mut self) -> Result<Vec<u8>> {
        let msg = self.receive().await?;
        match msg {
            Message::Binary(data) => Ok(data.to_vec()),
            _ => anyhow::bail!("Expected binary message, got {:?}", msg),
        }
    }

    pub async fn close(mut self) -> Result<()> {
        self.stream
            .close(None)
            .await
            .context("Failed to close WebSocket connection")?;
        Ok(())
    }

    pub async fn send_control_message(&mut self, msg: ControlMessage) -> Result<()> {
        let json = serde_json::to_string(&msg).context("Failed to serialize control message")?;
        crate::logger::log_debug(&format!("Sending control message: {}", json));
        self.send_text(&json).await
    }

    pub async fn receive_control_message(&mut self) -> Result<ControlMessage> {
        let text = self.receive_text().await?;
        crate::logger::log_debug(&format!("Received control message: {}", text));
        serde_json::from_str(&text).context("Failed to parse control message")
    }
}
