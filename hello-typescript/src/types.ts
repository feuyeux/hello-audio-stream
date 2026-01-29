/**
 * Type definitions for the audio stream client
 */

export interface Config {
  server: string;
  input: string;
  output: string;
  verbose: boolean;
}

export interface ControlMessage {
  type: "START" | "STARTED" | "STOP" | "STOPPED" | "GET" | "ERROR";
  streamId?: string;
  offset?: number;
  length?: number;
  message?: string;
}

export interface VerificationResult {
  passed: boolean;
  originalSize: number;
  downloadedSize: number;
  originalChecksum: string;
  downloadedChecksum: string;
}

export interface PerformanceReport {
  uploadDurationMs: number;
  uploadThroughputMbps: number;
  downloadDurationMs: number;
  downloadThroughputMbps: number;
  totalDurationMs: number;
  averageThroughputMbps: number;
}
