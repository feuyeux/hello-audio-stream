#!/usr/bin/env node
/**
 * Audio Server Application - TypeScript Implementation
 * Main entry point for the audio streaming server.
 * Matches Java AudioServerApplication structure and functionality.
 */

import { AudioWebSocketServer } from "./network/AudioWebSocketServer";
import { StreamManager } from "./memory/StreamManager";
import { MemoryPoolManager } from "./memory/MemoryPoolManager";

interface ServerConfig {
  host: string;
  port: number;
  path: string;
  cacheDir: string;
  bufferSize: number;
  poolSize: number;
  verbose: boolean;
}

class AudioServerApplication {
  private config: ServerConfig;
  private webSocketServer: AudioWebSocketServer | null = null;
  private streamManager: StreamManager | null = null;
  private memoryPoolManager: MemoryPoolManager | null = null;
  private statisticsInterval: NodeJS.Timeout | null = null;

  constructor(config: ServerConfig) {
    this.config = config;
  }

  async start(): Promise<void> {
    console.log("Starting Audio Server Application...");
    console.log(`Node.js Version: ${process.version}`);

    // Initialize components
    console.log(
      `Initializing StreamManager with cache directory: ${this.config.cacheDir}`,
    );
    this.streamManager = StreamManager.getInstance(this.config.cacheDir);

    console.log(
      `Initializing MemoryPoolManager singleton with ${this.config.poolSize} buffers of ${this.config.bufferSize} bytes`,
    );
    this.memoryPoolManager = MemoryPoolManager.getInstance(
      this.config.bufferSize,
      this.config.poolSize,
    );

    try {
      this.webSocketServer = new AudioWebSocketServer(
        this.config.host,
        this.config.port,
        this.config.path,
        this.streamManager,
      );
      this.webSocketServer.start();

      this.startStatisticsTimer();

      console.log(
        `Audio Server Application started successfully on port ${this.config.port}`,
      );
      console.log(
        `WebSocket endpoint: ws://${this.config.host}:${this.config.port}${this.config.path}`,
      );

      // Setup shutdown handlers
      process.on("SIGINT", () => this.shutdown());
      process.on("SIGTERM", () => this.shutdown());
    } catch (error) {
      console.error("Failed to start application:", error);
      process.exit(1);
    }
  }

  private startStatisticsTimer(): void {
    this.statisticsInterval = setInterval(() => {
      this.logStatistics();
    }, 30000); // 30 seconds
  }

  private logStatistics(): void {
    if (!this.streamManager || !this.memoryPoolManager) return;

    console.log("=== Application Statistics ===");
    console.log(
      `Stream Manager - Active Streams: ${this.streamManager.listActiveStreams().length}`,
    );
    console.log(
      `Memory Pool - Available: ${this.memoryPoolManager.getAvailableBuffers()} / ${this.memoryPoolManager.getTotalBuffers()}`,
    );

    const memUsage = process.memoryUsage();
    console.log(
      `Process Memory - Heap: ${(memUsage.heapUsed / 1024 / 1024).toFixed(2)} MB / ${(memUsage.heapTotal / 1024 / 1024).toFixed(2)} MB`,
    );
    console.log("============================");
  }

  shutdown(): void {
    console.log("Shutting down Audio Server Application...");

    if (this.statisticsInterval) {
      clearInterval(this.statisticsInterval);
    }

    if (this.webSocketServer) {
      this.webSocketServer.stop();
    }

    // Cleanup old streams before shutdown
    if (this.streamManager) {
      this.streamManager.cleanupOldStreams();
    }

    console.log("Audio Server Application shutdown complete");
    process.exit(0);
  }
}

function parseArgs(): ServerConfig {
  const args = process.argv.slice(2);
  const config: ServerConfig = {
    host: "0.0.0.0",
    port: 8080,
    path: "/audio",
    cacheDir: "cache",
    bufferSize: 65536,
    poolSize: 100,
    verbose: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case "--host":
        config.host = args[++i];
        break;
      case "--port":
        config.port = parseInt(args[++i]);
        break;
      case "--path":
        config.path = args[++i];
        break;
      case "--cache-dir":
        config.cacheDir = args[++i];
        break;
      case "--buffer-size":
        config.bufferSize = parseInt(args[++i]);
        break;
      case "--pool-size":
        config.poolSize = parseInt(args[++i]);
        break;
      case "--verbose":
      case "-v":
        config.verbose = true;
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
        break;
    }
  }

  return config;
}

function printHelp(): void {
  console.log(`
Audio Stream Server - TypeScript Implementation

Usage: node AudioServerApplication.js [options]

Options:
  --host <address>       Host address to bind to (default: 0.0.0.0)
  --port <number>        Port number to listen on (default: 8080)
  --path <path>          WebSocket endpoint path (default: /audio)
  --cache-dir <dir>      Cache directory for stream files (default: cache)
  --buffer-size <bytes>  Buffer size in bytes (default: 65536)
  --pool-size <number>   Number of buffers in pool (default: 100)
  --verbose, -v          Enable verbose logging
  --help, -h             Display this help message
`);
}

async function main(): Promise<void> {
  const config = parseArgs();

  console.log("=".repeat(60));
  console.log("Audio Stream Server - TypeScript Implementation");
  console.log("=".repeat(60));

  const app = new AudioServerApplication(config);
  await app.start();
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
