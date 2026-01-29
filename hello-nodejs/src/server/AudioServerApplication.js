#!/usr/bin/env node

/**
 * Audio Server Application - Main entry point for Node.js audio stream server.
 * Coordinates server initialization and lifecycle management.
 */

import { AudioWebSocketServer } from "./network/AudioWebSocketServer.js";

/**
 * Main server application class.
 */
export class AudioServerApplication {
  constructor(port = 8080, path = "/audio") {
    this.port = port;
    this.path = path;
    this.server = null;
  }

  /**
   * Start the server application.
   */
  start() {
    console.log("Starting Audio Server Application...");

    // Create and start WebSocket server
    this.server = new AudioWebSocketServer(this.port, this.path);
    this.server.start();

    // Handle graceful shutdown
    this.setupShutdownHandlers();
  }

  /**
   * Stop the server application.
   */
  stop() {
    console.log("Stopping Audio Server Application...");
    if (this.server) {
      this.server.stop();
    }
  }

  /**
   * Setup handlers for graceful shutdown.
   */
  setupShutdownHandlers() {
    process.on("SIGINT", () => {
      console.log("Received SIGINT signal");
      this.stop();
      process.exit(0);
    });

    process.on("SIGTERM", () => {
      console.log("Received SIGTERM signal");
      this.stop();
      process.exit(0);
    });
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  // Parse command line arguments
  let port = 8080;
  let path = "/audio";

  for (let i = 2; i < process.argv.length; i++) {
    if (process.argv[i] === "--port" && i + 1 < process.argv.length) {
      port = parseInt(process.argv[i + 1], 10);
      i++;
    } else if (process.argv[i] === "--path" && i + 1 < process.argv.length) {
      path = process.argv[i + 1];
      i++;
    }
  }

  const app = new AudioServerApplication(port, path);
  app.start();
}
