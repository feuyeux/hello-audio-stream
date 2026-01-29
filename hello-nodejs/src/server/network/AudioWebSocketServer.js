/**
 * Audio WebSocket server for handling client connections.
 * Manages WebSocket lifecycle and delegates message handling.
 */

import { WebSocketServer } from "ws";
import { StreamManager } from "../memory/StreamManager.js";
import { MemoryPoolManager } from "../memory/MemoryPoolManager.js";
import { WebSocketMessageHandler } from "../handler/WebSocketMessageHandler.js";

/**
 * WebSocket server for handling audio stream uploads and downloads.
 */
export class AudioWebSocketServer {
  /**
   * Initialize WebSocket server.
   *
   * @param {number} port - Port number to listen on
   * @param {string} path - WebSocket endpoint path
   */
  constructor(port = 8080, path = "/audio") {
    this.port = port;
    this.path = path;
    this.clients = new Set();
    this.streamManager = StreamManager.getInstance();
    this.memoryPool = MemoryPoolManager.getInstance();
    this.messageHandler = new WebSocketMessageHandler(this.streamManager);
    this.wss = null;

    console.log(`AudioWebSocketServer initialized on port ${port}${path}`);
  }

  /**
   * Start WebSocket server.
   */
  start() {
    this.wss = new WebSocketServer({
      port: this.port,
      maxPayload: 100 * 1024 * 1024,
    });

    this.wss.on("connection", (ws, req) => {
      this.handleClient(ws, req);
    });

    console.log(
      `WebSocket server started on ws://0.0.0.0:${this.port}${this.path}`,
    );
  }

  /**
   * Stop WebSocket server.
   */
  stop() {
    if (this.wss) {
      this.wss.close(() => {
        console.log("WebSocket server stopped");
      });
    }
  }

  /**
   * Handle a client connection.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {object} req - HTTP request object
   */
  handleClient(ws, req) {
    const clientAddr = req.socket.remoteAddress || "unknown";
    console.log(`Client connected: ${clientAddr}`);

    // Register client
    this.clients.add(ws);

    ws.on("message", async (message) => {
      await this.messageHandler.handleMessage(ws, message);
    });

    ws.on("close", () => {
      console.log(`Client disconnected: ${clientAddr}`);
      this.clients.delete(ws);
      this.messageHandler.cleanupClient(ws);
    });

    ws.on("error", (error) => {
      console.error(`Error on client ${clientAddr}:`, error);
    });
  }
}
