/**
 * WebSocket message handler using legacy protocol.
 *
 * Protocol:
 * - Text messages: {"type":"START|STOP|GET", "streamId":"xxx", ...}
 * - Binary frames: raw audio data
 */

import { MessageType } from "./MessageType.js";
import { WebSocketMessage } from "./WebSocketMessage.js";

export class WebSocketMessageHandler {
  /**
   * Create a WebSocketMessageHandler.
   *
   * @param {object} streamManager - StreamManager instance
   */
  constructor(streamManager) {
    this.streamManager = streamManager;
    this.connectionCounter = 0;
  }

  /**
   * Handle a new WebSocket connection.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {object} req - HTTP request object
   */
  handleConnection(ws, req) {
    const connectionId = `conn-${++this.connectionCounter}`;
    const clientAddr = req.socket.remoteAddress || "unknown";
    
    console.log(`New connection established: ${connectionId} from ${clientAddr}`);

    // Initialize connection state
    ws.connectionId = connectionId;
    ws.streamId = null;

    // Send connection established message
    this.sendResponse(ws, WebSocketMessage.connected(connectionId, "Connection established"));

    // Set up message handler
    ws.on("message", async (message) => {
      await this.handleMessage(ws, message);
    });

    // Set up close handler
    ws.on("close", () => {
      console.log(`Connection closed: ${connectionId}`);
      if (ws.streamId) {
        console.log(`Cleaning up stream: ${ws.streamId}`);
      }
    });

    // Set up error handler
    ws.on("error", (error) => {
      console.error(`Error on connection ${connectionId}:`, error);
    });
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
        // ws may deliver text as Buffer in some runtimes; try JSON first.
        const textCandidate = message.toString("utf8");
        if (textCandidate.length > 0 && textCandidate.trim().startsWith("{")) {
          try {
            JSON.parse(textCandidate);
            await this.handleTextMessage(ws, textCandidate);
            return;
          } catch {
            // Not JSON control text, continue as binary payload.
          }
        }
        await this.handleBinaryMessage(ws, message);
      } else {
        // Text message (JSON control message)
        await this.handleTextMessage(ws, message.toString());
      }
    } catch (error) {
      console.error(`Error handling message for ${ws.connectionId}:`, error);
      this.sendErrorResponse(ws, error.message);
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
      const msg = WebSocketMessage.fromJson(message);
      const messageType = msg.getMessageType();

      if (!messageType) {
        console.warn(`Unknown message type: ${msg.type}`);
        this.sendErrorResponse(ws, `Unknown message type: ${msg.type}`);
        return;
      }

      console.debug(`Received ${messageType} message from ${ws.connectionId}`);

      switch (messageType) {
        case MessageType.START:
          await this.handleStartMessage(ws, msg);
          break;
        case MessageType.STOP:
          await this.handleStopMessage(ws, msg);
          break;
        case MessageType.GET:
          await this.handleGetMessage(ws, msg);
          break;
        default:
          console.warn(`Unhandled message type: ${messageType}`);
          this.sendErrorResponse(ws, `Unhandled message type: ${messageType}`);
      }
    } catch (error) {
      console.error(`Error parsing JSON message from ${ws.connectionId}:`, error);
      this.sendErrorResponse(ws, "Invalid JSON format");
    }
  }

  /**
   * Handle START message (create new stream).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Message data
   */
  async handleStartMessage(ws, msg) {
    let streamId = msg.streamId;
    
    if (!streamId || streamId.trim() === "") {
      console.warn(`Start message missing streamId, using connectionId as streamId`);
      streamId = ws.connectionId;
    }

    // Create stream in StreamManager
    if (await this.streamManager.createStream(streamId)) {
      ws.streamId = streamId;
      console.log(`Stream started with ID: ${streamId} for connection: ${ws.connectionId}`);
      this.sendResponse(ws, WebSocketMessage.started(streamId, "Stream started"));
    } else {
      console.error(`Failed to create stream: ${streamId}`);
      this.sendErrorResponse(ws, "Failed to create stream");
    }
  }

  /**
   * Handle STOP message (finalize stream).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Message data
   */
  async handleStopMessage(ws, msg) {
    let streamId = msg.streamId;
    
    if (!streamId || streamId.trim() === "") {
      streamId = ws.streamId;
    }

    if (!streamId) {
      this.sendErrorResponse(ws, "No active stream to stop");
      return;
    }

    // Finalize stream
    if (await this.streamManager.finalizeStream(streamId)) {
      console.log(`Stream stopped: ${streamId} for connection: ${ws.connectionId}`);
      this.sendResponse(ws, WebSocketMessage.stopped(streamId, "Stream stopped"));
      ws.streamId = null;
    } else {
      console.error(`Failed to finalize stream: ${streamId}`);
      this.sendErrorResponse(ws, "Failed to finalize stream");
    }
  }

  /**
   * Handle GET message (read stream data).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} msg - Message data
   */
  async handleGetMessage(ws, msg) {
    const streamId = msg.streamId;
    const offset = msg.offset;
    const length = msg.length;

    if (!streamId) {
      this.sendErrorResponse(ws, "Missing streamId in get request");
      return;
    }

    if (offset === null || offset === undefined || length === null || length === undefined) {
      this.sendErrorResponse(ws, "Missing offset or length in get request");
      return;
    }

    try {
      // Read data from stream
      const data = await this.streamManager.readChunk(streamId, offset, length);

      if (data && data.length > 0) {
        ws.send(data);
        console.debug(`Sent ${data.length} bytes for stream: ${streamId} offset: ${offset}`);
      } else {
        this.sendErrorResponse(ws, `No data available at offset ${offset}`);
      }
    } catch (error) {
      console.error(`Error processing get request for stream: ${streamId}`, error);
      this.sendErrorResponse(ws, `Failed to retrieve data: ${error.message}`);
    }
  }

  /**
   * Handle binary audio data.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {Buffer} data - Binary audio data
   */
  async handleBinaryMessage(ws, data) {
    if (!ws.streamId) {
      console.warn(`Received binary data without active stream for connection: ${ws.connectionId}`);
      this.sendErrorResponse(ws, "No active stream. Send start message first.");
      return;
    }

    try {
      await this.streamManager.writeChunk(ws.streamId, data);
      console.debug(`Wrote ${data.length} bytes to stream: ${ws.streamId}`);
    } catch (error) {
      console.error(`Error writing binary data for stream: ${ws.streamId}`, error);
      this.sendErrorResponse(ws, `Failed to write data: ${error.message}`);
    }
  }

  /**
   * Send a response message to client.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {WebSocketMessage} response - Response message
   */
  sendResponse(ws, response) {
    try {
      ws.send(response.toJson());
    } catch (error) {
      console.error(`Error sending response to ${ws.connectionId}:`, error);
    }
  }

  /**
   * Send an error message to client.
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {string} errorMessage - Error message
   */
  sendErrorResponse(ws, errorMessage) {
    try {
      const error = WebSocketMessage.error(errorMessage);
      ws.send(error.toJson());
      console.error(`Sent error to ${ws.connectionId}: ${errorMessage}`);
    } catch (error) {
      console.error(`Error sending error response to ${ws.connectionId}:`, error);
    }
  }

  /**
   * Cleanup client-specific state on disconnect.
   *
   * @param {WebSocket} ws - WebSocket connection
   */
  cleanupClient(ws) {
    ws.streamId = null;
  }
}
