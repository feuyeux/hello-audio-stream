use anyhow::{anyhow, Result};
use futures_util::{SinkExt, StreamExt};
use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as WsMessage};

use crate::server::message::Message;

const CHUNK_SIZE: usize = 64 * 1024; // 64 KB

type WsConn = tokio_tungstenite::WebSocketStream<
    tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
>;

/// Client for the audio stream cache server.
pub struct Client {
    ws: WsConn,
}

impl Client {
    /// Connect to the server and wait for the CONNECTED message.
    pub async fn connect(server_uri: &str) -> Result<Self> {
        let (ws, _) = connect_async(server_uri).await
            .map_err(|e| anyhow!("Connect failed: {}", e))?;
        let mut client = Self { ws };

        // Expect CONNECTED
        let msg = client.recv_json().await?;
        if msg.command != "CONNECTED" {
            return Err(anyhow!("Expected CONNECTED, got: {}", msg.command));
        }
        println!("Connected (conn_id={})", msg.stream_id.as_deref().unwrap_or("?"));
        Ok(client)
    }

    /// Upload a local file to the server under the given stream ID.
    pub async fn upload(&mut self, file_path: &str, stream_id: &str) -> Result<()> {
        // CREATE
        self.send_json(&Message {
            command: "CREATE".to_string(),
            stream_id: Some(stream_id.to_string()),
            ..Default::default()
        }).await?;
        let r = self.recv_json().await?;
        if r.command != "CREATED" {
            return Err(anyhow!("Expected CREATED, got {} - {:?}", r.command, r.message));
        }

        // Binary chunks
        let mut file = File::open(file_path)?;
        let mut buf = vec![0u8; CHUNK_SIZE];
        loop {
            let n = file.read(&mut buf)?;
            if n == 0 { break; }
            self.ws.send(WsMessage::Binary(buf[..n].to_vec().into())).await?;
        }

        // COMPLETE
        self.send_json(&Message {
            command: "COMPLETE".to_string(),
            ..Default::default()
        }).await?;
        let r = self.recv_json().await?;
        if r.command != "COMPLETED" {
            return Err(anyhow!("Expected COMPLETED, got {} - {:?}", r.command, r.message));
        }
        println!("Upload complete: {}", stream_id);
        Ok(())
    }

    /// Download a stream from the server and write it to a local file.
    pub async fn download(&mut self, stream_id: &str, output_path: &str) -> Result<u64> {
        if let Some(parent) = Path::new(output_path).parent() {
            std::fs::create_dir_all(parent)?;
        }
        let mut out = File::create(output_path)?;
        let mut offset: u64 = 0;

        loop {
            self.send_json(&Message {
                command: "READ".to_string(),
                stream_id: Some(stream_id.to_string()),
                offset: Some(offset),
                length: Some(CHUNK_SIZE),
                ..Default::default()
            }).await?;

            match self.ws.next().await {
                Some(Ok(WsMessage::Binary(data))) => {
                    if data.is_empty() { break; }
                    out.write_all(&data)?;
                    offset += data.len() as u64;
                }
                Some(Ok(WsMessage::Text(text))) => {
                    let msg: Message = serde_json::from_str(&text)
                        .map_err(|e| anyhow!("Invalid JSON: {}", e))?;
                    if msg.command == "ERROR" { break; }
                    return Err(anyhow!("Unexpected text during download: {}", msg.command));
                }
                Some(Err(e)) => return Err(anyhow!("WebSocket error: {}", e)),
                None | Some(Ok(_)) => break,
            }
        }

        println!("Download complete: {} ({} bytes)", stream_id, offset);
        Ok(offset)
    }

    /// Verify two files match via SHA-256.
    pub fn verify(path_a: &str, path_b: &str) -> Result<bool> {
        let hash_a = sha256_file(path_a)?;
        let hash_b = sha256_file(path_b)?;
        let ok = hash_a == hash_b;
        if ok { println!("Verification OK: files match"); }
        else { eprintln!("Verification FAILED: files differ"); }
        Ok(ok)
    }

    async fn send_json(&mut self, msg: &Message) -> Result<()> {
        let json = serde_json::to_string(msg)?;
        self.ws.send(WsMessage::Text(json.into())).await?;
        Ok(())
    }

    async fn recv_json(&mut self) -> Result<Message> {
        loop {
            match self.ws.next().await {
                Some(Ok(WsMessage::Text(text))) => {
                    return serde_json::from_str(&text)
                        .map_err(|e| anyhow!("Invalid JSON: {}", e));
                }
                Some(Ok(WsMessage::Ping(_) | WsMessage::Pong(_))) => continue,
                Some(Ok(other)) => return Err(anyhow!("Expected text, got: {:?}", other)),
                Some(Err(e)) => return Err(anyhow!("WebSocket error: {}", e)),
                None => return Err(anyhow!("Connection closed unexpectedly")),
            }
        }
    }
}

fn sha256_file(path: &str) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

/// Entry point called from bin/client.rs.
pub async fn run(server: &str, input: &str, output: &str) -> Result<()> {
    use std::time::Instant;

    println!("========================================");
    println!("Starting Audio Stream Client");
    println!("Input:   {}", input);
    println!("Output:  {}", output);
    println!("========================================");

    let stream_id = format!("stream-{}", rand::random::<u32>());
    let mut client = Client::connect(server).await?;
    let file_size = std::fs::metadata(input)?.len();
    println!("File size: {} bytes", file_size);

    println!("[1/3] Uploading...");
    let t0 = Instant::now();
    client.upload(input, &stream_id).await?;
    let upload_ms = t0.elapsed().as_millis();
    println!("Upload: {}ms ({:.2} Mbps)", upload_ms, mbps(file_size, upload_ms));

    tokio::time::sleep(std::time::Duration::from_secs(1)).await;

    println!("[2/3] Downloading...");
    let t1 = Instant::now();
    let downloaded = client.download(&stream_id, output).await?;
    let dl_ms = t1.elapsed().as_millis();
    println!("Download: {}ms ({:.2} Mbps)", dl_ms, mbps(downloaded, dl_ms));

    println!("[3/3] Verifying...");
    let ok = Client::verify(input, output)?;
    println!("Result: {}", if ok { "SUCCESS" } else { "FAILED" });
    Ok(())
}

fn mbps(bytes: u64, ms: u128) -> f64 {
    if ms == 0 { return 0.0; }
    (bytes as f64 * 8.0) / (ms as f64 * 1_000.0)
}
