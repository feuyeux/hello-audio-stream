use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "audio_stream_client")]
#[command(about = "Audio Stream Cache Client - Rust Implementation", long_about = None)]
pub struct Config {
    /// Input audio file path
    #[arg(long, value_name = "FILE")]
    pub input: String,

    /// WebSocket server URI
    #[arg(long, default_value = "ws://localhost:8080/audio")]
    pub server: String,

    /// Output file path
    #[arg(long, value_name = "FILE", default_value = "")]
    pub output: String,

    /// Enable verbose logging
    #[arg(long, short = 'v')]
    pub verbose: bool,
}

impl Config {
    pub fn parse() -> Self {
        let mut config = <Config as Parser>::parse();

        // Generate default output path if not provided
        if config.output.is_empty() {
            config.output = Self::generate_default_output(&config.input);
        }

        config
    }

    fn generate_default_output(input_path: &str) -> String {
        let path = PathBuf::from(input_path);
        let filename = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("output.mp3");

        let timestamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
        format!("audio/output/output-{}-{}", timestamp, filename)
    }
}
