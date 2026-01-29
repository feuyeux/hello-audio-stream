/**
 * WebSocket server for audio streaming.
 * Handles client connections and message routing.
 * Matches C++ WebSocketServer and Java AudioWebSocketServer functionality.
 */

import * as WebSocket from "ws";
import { StreamManager } from "../memory/StreamManager";
import { MemoryPoolManager } from "../memory/MemoryPoolManager";
import { WebSocketMessageHandler } from "../handler/WebSocketMessageHandler";

export class AudioWebSocketServer {
  private host: string;
  private port: number;
  private path: string;
  private server: WebSocket.Server | null;
  private streamManager: StreamManager;
  private memoryPool: MemoryPoolManager;
  private connectionHandlers: Map<WebSocket, WebSocketMessageHandler>;

  constructor(
    host: string,
    port: number,
    path: string,
    streamManager: StreamManager,
  ) {
    this.host = host;
    this.port = port;
    this.path = path;
    this.server = null;
    this.streamManager = streamManager;
    this.memoryPool = MemoryPoolManager.getInstance();
    this.connectionHandlers = new Map();

    console.log(`AudioWebSocketServer initialized on ${host}:${port}${path}`);
  }

  start(): void {
    this.server = new WebSocket.Server({
      host: this.host,
      port: this.port,
      path: this.path,
      maxPayload: 100 * 1024 * 1024, // 100MB max message size
    });

    this.server.on("connection", (ws: WebSocket) => {
      this.handleConnection(ws);
    });

    this.server.on("error", (error: Error) => {
      console.error("WebSocket server error:", error);
    });

    console.log(
      `WebSocket server started on ws://${this.host}:${this.port}${this.path}`,
    );
  }

  stop(): void {
    if (this.server) {
      this.server.close(() => {
        console.log("WebSocket server stopped");
      });
    }
  }

  private handleConnection(ws: WebSocket): void {
    const clientAddr = `${(ws as any)._socket?.remoteAddress}:${(ws as any)._socket?.remotePort}`;
    console.log(`Client connected: ${clientAddr}`);

    // Create a handler for this connection
    const handler = new WebSocketMessageHandler(this.streamManager);
    this.connectionHandlers.set(ws, handler);

    ws.on("message", (message: WebSocket.Data) => {
      handler.handleMessage(ws, message);
    });

    ws.on("close", () => {
      console.log(`Client disconnected: ${clientAddr}`);
      this.connectionHandlers.delete(ws);
    });

    ws.on("error", (error: Error) => {
      console.error(`Client error ${clientAddr}:`, error);
      this.connectionHandlers.delete(ws);
    });
  }
}
