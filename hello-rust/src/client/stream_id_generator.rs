// Stream ID generator for creating unique stream identifiers

pub fn generate_stream_id() -> String {
    let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let random: String = (0..8)
        .map(|_| format!("{:x}", rand::random::<u8>() % 16))
        .collect();
    format!("stream-{}-{}", timestamp, random)
}
