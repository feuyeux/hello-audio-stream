/**
 * WebSocket message handler for processing client messages.
 * Separates message handling logic from server connection management.
 * Matches Java WebSocketMessageHandler functionality.
 */

import * as WebSocket from "ws";
import { StreamManager } from "../memory/StreamManager";
import {
  WebSocketMessage,
  IWebSocketMessage,
  MessageType,
  getMessageType,
} from "./WebSocketMessage";

export class WebSocketMessageHandler {
  private streamManager: StreamManager;
  private currentStreamId: string | null = null;

  constructor(streamManager: StreamManager) {
    this.streamManager = streamManager;
  }

  handleMessage(ws: WebSocket, message: WebSocket.Data): void {
    try {
      // Check if message is binary (audio data)
      if (Buffer.isBuffer(message)) {
        console.log(`Received binary message: ${message.length} bytes`);
        // Check if it might be a text message sent as binary
        if (message.length < 1000) {
          try {
            const text = message.toString("utf8");
            console.log(`Binary message content (as text): ${text}`);
            const parsed = JSON.parse(text);
            if (parsed.type) {
              console.log(
                `Binary message is actually JSON control message, processing as text`,
              );
              this.handleTextMessage(ws, text);
              return;
            }
          } catch (e) {
            // Not JSON, treat as binary
            console.log(`Binary message is not JSON, treating as binary data`);
          }
        }
        this.handleBinaryMessage(ws, message);
      } else if (typeof message === "string") {
        // Text message (JSON control message)
        console.log(`Received text message: ${message}`);
        this.handleTextMessage(ws, message);
      } else if (Array.isArray(message)) {
        // Array of buffers - concatenate them
        console.log(`Received array of buffers: ${message.length} buffers`);
        const buffer = Buffer.concat(
          message.map((m) => (Buffer.isBuffer(m) ? m : Buffer.from(m))),
        );
        this.handleMessage(ws, buffer);
      }
    } catch (error) {
      console.error("Error handling message:", error);
      this.sendError(ws, String(error));
    }
  }

  private handleTextMessage(ws: WebSocket, message: string): void {
    try {
      const msg = WebSocketMessage.fromJSON(message);
      const msgType = getMessageType(msg.type);

      if (!msgType) {
        console.warn(`Unknown message type: ${msg.type}`);
        this.sendError(ws, `Unknown message type: ${msg.type}`);
        return;
      }

      switch (msgType) {
        case MessageType.START:
          this.handleStart(ws, msg);
          break;
        case MessageType.STOP:
          this.handleStop(ws, msg);
          break;
        case MessageType.GET:
          this.handleGet(ws, msg);
          break;
        default:
          console.warn(`Unhandled message type: ${msgType}`);
          this.sendError(ws, `Unhandled message type: ${msgType}`);
      }
    } catch (error) {
      console.error("Invalid JSON message:", error);
      this.sendError(ws, "Invalid JSON format");
    }
  }

  private handleBinaryMessage(ws: WebSocket, data: Buffer): void {
    // Binary data belongs to current stream
    if (!this.currentStreamId) {
      console.error(
        `Received binary data without active stream (currentStreamId is ${this.currentStreamId})`,
      );
      return;
    }

    // Write data to stream
    if (this.streamManager.writeChunk(this.currentStreamId, data)) {
      console.log(
        `Wrote ${data.length} bytes to stream ${this.currentStreamId}`,
      );
    } else {
      console.error(
        `Failed to write binary data to stream ${this.currentStreamId}`,
      );
    }
  }

  private handleStart(ws: WebSocket, msg: WebSocketMessage): void {
    const streamId = msg.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Create stream and set currentStreamId BEFORE sending response
    if (this.streamManager.createStream(streamId)) {
      this.currentStreamId = streamId;
      console.log(`Stream started: ${streamId}, currentStreamId set`);
      const response = WebSocketMessage.started(streamId);
      ws.send(response.toJSON());
    } else {
      this.sendError(ws, `Failed to create stream: ${streamId}`);
    }
  }

  private handleStop(ws: WebSocket, msg: WebSocketMessage): void {
    const streamId = msg.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Finalize stream
    if (this.streamManager.finalizeStream(streamId)) {
      this.currentStreamId = null;
      const response = WebSocketMessage.stopped(streamId);
      ws.send(response.toJSON());
      console.log(`Stream finalized: ${streamId}`);
    } else {
      this.sendError(ws, `Failed to finalize stream: ${streamId}`);
    }
  }

  private handleGet(ws: WebSocket, msg: WebSocketMessage): void {
    const streamId = msg.streamId;
    const offset = msg.offset ?? 0;
    const length = msg.length ?? 65536;

    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Read data from stream
    const chunkData = this.streamManager.readChunk(streamId, offset, length);

    if (chunkData && chunkData.length > 0) {
      // Send binary data
      ws.send(chunkData);
      console.log(
        `Sent ${chunkData.length} bytes for stream ${streamId} at offset ${offset}`,
      );
    } else {
      this.sendError(ws, `Failed to read from stream: ${streamId}`);
    }
  }

  private sendError(ws: WebSocket, message: string): void {
    const response = WebSocketMessage.error(message);
    ws.send(response.toJSON());
    console.error(`Sent error to client: ${message}`);
  }
}
