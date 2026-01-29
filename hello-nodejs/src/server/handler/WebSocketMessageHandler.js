/**
 * WebSocket message handler for processing client messages.
 * Handles START, STOP, and GET message types.
 */

import {
  WebSocketMessage,
  MessageType,
  getMessageType,
} from "./WebSocketMessage.js";

export class WebSocketMessageHandler {
  constructor(streamManager) {
    this.streamManager = streamManager;
    this.activeStreams = new Map(); // Maps client to active streamId
  }

  /**
   * Handle a message from a client.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {Buffer|String} message - Message data
   */
  async handleMessage(ws, message) {
    try {
      // Check if message is binary (audio data)
      if (Buffer.isBuffer(message)) {
        // Check if it might be a text message sent as binary
        if (message.length < 1000) {
          try {
            const text = message.toString("utf8");
            const parsed = JSON.parse(text);
            if (parsed.type) {
              console.debug(
                `Binary message is actually JSON control message, processing as text`,
              );
              await this.handleTextMessage(ws, text);
              return;
            }
          } catch (e) {
            // Not JSON, treat as binary
          }
        }
        await this.handleBinaryMessage(ws, message);
      } else {
        // Text message (JSON control message)
        await this.handleTextMessage(ws, message.toString());
      }
    } catch (error) {
      console.error("Error handling message:", error);
      this.sendError(ws, error.message);
    }
  }

  /**
   * Handle a text (JSON) control message.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {string} message - JSON message string
   */
  async handleTextMessage(ws, message) {
    try {
      const msg = WebSocketMessage.fromJSON(message);
      const msgType = getMessageType(msg.type);

      if (msgType === null) {
        console.warn(`Unknown message type: ${msg.type}`);
        this.sendError(ws, `Unknown message type: ${msg.type}`);
        return;
      }

      switch (msgType) {
        case MessageType.START:
          await this.handleStart(ws, msg);
          break;
        case MessageType.STOP:
          await this.handleStop(ws, msg);
          break;
        case MessageType.GET:
          await this.handleGet(ws, msg);
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

  /**
   * Handle binary audio data.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {Buffer} data - Binary audio data
   */
  async handleBinaryMessage(ws, data) {
    // Get active stream ID for this client
    const streamId = this.activeStreams.get(ws);

    if (!streamId) {
      console.warn("Received binary data but no active stream for client");
      return;
    }

    console.debug(
      `Received ${data.length} bytes of binary data for stream ${streamId}`,
    );

    // Write to stream
    await this.streamManager.writeChunk(streamId, data);
  }

  /**
   * Handle START message (create new stream).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Parsed message
   */
  async handleStart(ws, msg) {
    const streamId = msg.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Create stream
    if (await this.streamManager.createStream(streamId)) {
      // Register this client with the stream
      this.activeStreams.set(ws, streamId);

      const response = WebSocketMessage.started(streamId);
      ws.send(response.toJSON());
      console.log(`Stream started: ${streamId}`);
    } else {
      this.sendError(ws, `Failed to create stream: ${streamId}`);
    }
  }

  /**
   * Handle STOP message (finalize stream).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Parsed message
   */
  async handleStop(ws, msg) {
    const streamId = msg.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Finalize stream
    if (await this.streamManager.finalizeStream(streamId)) {
      const response = WebSocketMessage.stopped(streamId);
      ws.send(response.toJSON());
      console.log(`Stream finalized: ${streamId}`);

      // Unregister stream from client
      this.activeStreams.delete(ws);
    } else {
      this.sendError(ws, `Failed to finalize stream: ${streamId}`);
    }
  }

  /**
   * Handle GET message (read stream data).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Parsed message
   */
  async handleGet(ws, msg) {
    const streamId = msg.streamId;
    const offset = msg.offset !== null ? msg.offset : 0;
    const length = msg.length !== null ? msg.length : 65536;

    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Read data from stream
    const chunkData = await this.streamManager.readChunk(
      streamId,
      offset,
      length,
    );

    if (chunkData && chunkData.length > 0) {
      // Send binary data
      ws.send(chunkData);
      console.debug(
        `Sent ${chunkData.length} bytes for stream ${streamId} at offset ${offset}`,
      );
    } else {
      this.sendError(ws, `Failed to read from stream: ${streamId}`);
    }
  }

  /**
   * Send an error message to client.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {string} message - Error message
   */
  sendError(ws, message) {
    const response = WebSocketMessage.error(message);
    ws.send(response.toJSON());
    console.error(`Sent error to client: ${message}`);
  }

  /**
   * Clean up client connection.
   *
   * @param {WebSocket} ws - WebSocket connection
   */
  cleanupClient(ws) {
    this.activeStreams.delete(ws);
  }
}
