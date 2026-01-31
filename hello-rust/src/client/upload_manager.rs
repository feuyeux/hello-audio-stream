use super::stream_id_generator;
use super::{
    file_manager,
    websocket_client::{ControlMessage, WebSocketClient},
};
use crate::logger;
use anyhow::Result;

pub async fn upload(
    ws_client: &mut WebSocketClient,
    file_path: &str,
    file_size: u64,
) -> Result<String> {
    // Generate unique stream ID (using short UUID format like Java)
    let stream_id = stream_id_generator::generate_short();
    logger::log_info(&format!("Generated stream ID: {}", stream_id));

    // Send START message
    let start_msg = ControlMessage {
        msg_type: "START".to_string(),
        stream_id: Some(stream_id.clone()),
        offset: None,
        length: None,
        message: None,
    };
    ws_client.send_control_message(start_msg).await?;
    logger::log_info("Sent START message, waiting for STARTED response...");

    // Wait for START_ACK
    let response = ws_client.receive_control_message().await?;
    logger::log_info(&format!(
        "Received response: msg_type='{}'",
        response.msg_type
    ));
    if response.msg_type != "STARTED" {
        anyhow::bail!("Unexpected response to START: {:?}", response);
    }

    // Upload file in chunks
    let mut offset = 0u64;
    let mut bytes_sent = 0u64;
    let mut last_progress = 0;

    while offset < file_size {
        let chunk_size =
            std::cmp::min(file_manager::CHUNK_SIZE as u64, file_size - offset) as usize;
        let chunk = file_manager::read_chunk(file_path, offset, chunk_size)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to read file chunk: {}", e))?;

        ws_client.send_binary(chunk).await?;

        offset += chunk_size as u64;
        bytes_sent += chunk_size as u64;

        // Report progress
        let progress = (bytes_sent * 100 / file_size) as usize;
        if progress >= last_progress + 25 && progress <= 100 {
            logger::log_info(&format!(
                "Upload progress: {}/{} bytes ({}%)",
                bytes_sent, file_size, progress
            ));
            last_progress = progress;
        }
    }

    // Ensure 100% is reported
    if last_progress < 100 {
        logger::log_info(&format!(
            "Upload progress: {}/{} bytes (100%)",
            file_size, file_size
        ));
    }

    // Send STOP message
    let stop_msg = ControlMessage {
        msg_type: "STOP".to_string(),
        stream_id: Some(stream_id.clone()),
        offset: None,
        length: None,
        message: None,
    };
    ws_client.send_control_message(stop_msg).await?;

    // Wait for STOP_ACK
    let response = ws_client.receive_control_message().await?;
    if response.msg_type != "STOPPED" {
        anyhow::bail!("Unexpected response to STOP: {:?}", response);
    }

    Ok(stream_id)
}
