use std::time::Instant;

pub struct PerformanceMonitor {
    file_size: u64,
    upload_start: Option<Instant>,
    upload_end: Option<Instant>,
    download_start: Option<Instant>,
    download_end: Option<Instant>,
}

pub struct PerformanceReport {
    pub upload_duration_ms: u64,
    pub upload_throughput_mbps: f64,
    pub download_duration_ms: u64,
    pub download_throughput_mbps: f64,
    pub total_duration_ms: u64,
    pub average_throughput_mbps: f64,
}

impl PerformanceMonitor {
    pub fn new(file_size: u64) -> Self {
        Self {
            file_size,
            upload_start: None,
            upload_end: None,
            download_start: None,
            download_end: None,
        }
    }

    pub fn start_upload(&mut self) {
        self.upload_start = Some(Instant::now());
    }

    pub fn end_upload(&mut self) {
        self.upload_end = Some(Instant::now());
    }

    pub fn start_download(&mut self) {
        self.download_start = Some(Instant::now());
    }

    pub fn end_download(&mut self) {
        self.download_end = Some(Instant::now());
    }

    pub fn get_report(&self) -> PerformanceReport {
        let upload_duration_ms = self
            .upload_end
            .unwrap()
            .duration_since(self.upload_start.unwrap())
            .as_millis() as u64;

        let download_duration_ms = self
            .download_end
            .unwrap()
            .duration_since(self.download_start.unwrap())
            .as_millis() as u64;

        let total_duration_ms = upload_duration_ms + download_duration_ms;

        // Throughput (Mbps) = (file_size_bytes * 8) / (duration_ms * 1_000_000)
        let upload_throughput_mbps =
            (self.file_size as f64 * 8.0) / (upload_duration_ms as f64 * 1_000_000.0);
        let download_throughput_mbps =
            (self.file_size as f64 * 8.0) / (download_duration_ms as f64 * 1_000_000.0);
        let average_throughput_mbps =
            (self.file_size as f64 * 2.0 * 8.0) / (total_duration_ms as f64 * 1_000_000.0);

        PerformanceReport {
            upload_duration_ms,
            upload_throughput_mbps,
            download_duration_ms,
            download_throughput_mbps,
            total_duration_ms,
            average_throughput_mbps,
        }
    }
}
