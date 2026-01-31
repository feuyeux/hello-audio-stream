// Stream ID generator for creating unique stream identifiers
// Matches Java StreamIdGenerator with short UUID format

pub fn generate_short() -> String {
    // Generate 8-character hex string (like Java's UUID.substring(0, 8))
    let random: String = (0..8)
        .map(|_| format!("{:02x}", rand::random::<u8>()))
        .collect();
    format!("stream-{}", random)
}

pub fn generate_stream_id() -> String {
    // Legacy method for backward compatibility
    let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let random: String = (0..8)
        .map(|_| format!("{:x}", rand::random::<u8>() % 16))
        .collect();
    format!("stream-{}-{}", timestamp, random)
}
