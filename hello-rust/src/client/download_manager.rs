use super::{
    file_manager,
    websocket_client::{ControlMessage, WebSocketClient},
};
use crate::logger;
use anyhow::{Context, Result};

pub async fn download(
    ws_client: &mut WebSocketClient,
    stream_id: &str,
    output_path: &str,
    file_size: u64,
) -> Result<()> {
    let mut offset = 0u64;
    let mut bytes_received = 0u64;
    let mut last_progress = 0;
    let mut is_first_chunk = true;

    while offset < file_size {
        let chunk_size =
            std::cmp::min(file_manager::CHUNK_SIZE as u64, file_size - offset) as usize;

        // Send GET message
        let get_msg = ControlMessage {
            msg_type: "GET".to_string(),
            stream_id: Some(stream_id.to_string()),
            offset: Some(offset),
            length: Some(chunk_size),
            message: None,
        };
        ws_client.send_control_message(get_msg).await?;

        // Receive binary data
        let data = ws_client.receive_binary().await?;

        // Write to file
        file_manager::write_chunk(output_path, &data, !is_first_chunk)
            .await
            .context("Failed to write downloaded chunk")?;

        is_first_chunk = false;
        offset += data.len() as u64;
        bytes_received += data.len() as u64;

        // Report progress
        let progress = (bytes_received * 100 / file_size) as usize;
        if progress >= last_progress + 25 && progress <= 100 {
            logger::log_info(&format!(
                "Download progress: {}/{} bytes ({}%)",
                bytes_received, file_size, progress
            ));
            last_progress = progress;
        }
    }

    // Ensure 100% is reported
    if last_progress < 100 {
        logger::log_info(&format!(
            "Download progress: {}/{} bytes (100%)",
            file_size, file_size
        ));
    }

    Ok(())
}
