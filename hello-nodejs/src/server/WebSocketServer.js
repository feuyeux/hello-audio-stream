/**
 * WebSocket server for audio streaming.
 * Handles client connections and message routing.
 * Matches Python WebSocketServer and Java AudioWebSocketServer functionality.
 */

const WebSocket = require("ws");
const fs = require("fs");
const path = require("path");

const StreamManager = require("./StreamManager");
const MemoryPoolManager = require("./MemoryPoolManager");

/**
 * WebSocket server for handling audio stream uploads and downloads.
 */
class WebSocketServer {
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
    this.wss = null;
    this.activeStreams = new Map(); // Maps client to active streamId

    console.log(`WebSocketServer initialized on port ${port}${path}`);
  }

  /**
   * Start WebSocket server.
   */
  start() {
    this.wss = new WebSocket.Server({
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
      await this.handleMessage(ws, message);
    });

    ws.on("close", () => {
      console.log(`Client disconnected: ${clientAddr}`);
      this.clients.delete(ws);
      this.activeStreams.delete(ws);
    });

    ws.on("error", (error) => {
      console.error(`Error on client ${clientAddr}:`, error);
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
      const data = JSON.parse(message);
      const msgType = data.type;

      if (msgType === "START") {
        await this.handleStart(ws, data);
      } else if (msgType === "STOP") {
        await this.handleStop(ws, data);
      } else if (msgType === "GET") {
        await this.handleGet(ws, data);
      } else {
        console.warn(`Unknown message type: ${msgType}`);
        this.sendError(ws, `Unknown message type: ${msgType}`);
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
   * @param {object} data - Message data containing streamId
   */
  async handleStart(ws, data) {
    const streamId = data.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Create stream
    if (await this.streamManager.createStream(streamId)) {
      // Register this client with the stream
      this.activeStreams.set(ws, streamId);

      const response = {
        type: "START_ACK",
        streamId: streamId,
        message: "Stream started successfully",
      };
      ws.send(JSON.stringify(response));
      console.log(`Stream started: ${streamId}`);
    } else {
      this.sendError(ws, `Failed to create stream: ${streamId}`);
    }
  }

  /**
   * Handle STOP message (finalize stream).
   *
   * @param {WebSocket} ws - WebSocket connection
   * @param {object} data - Message data containing streamId
   */
  async handleStop(ws, data) {
    const streamId = data.streamId;
    if (!streamId) {
      this.sendError(ws, "Missing streamId");
      return;
    }

    // Finalize stream
    if (await this.streamManager.finalizeStream(streamId)) {
      const response = {
        type: "STOP_ACK",
        streamId: streamId,
        message: "Stream finalized successfully",
      };
      ws.send(JSON.stringify(response));
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
   * @param {object} data - Message data containing streamId, offset, and length
   */
  async handleGet(ws, data) {
    const streamId = data.streamId;
    const offset = data.offset || 0;
    const length = data.length || 65536;

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
    const response = {
      type: "ERROR",
      message: message,
    };
    ws.send(JSON.stringify(response));
    console.error(`Sent error to client: ${message}`);
  }
}

module.exports = WebSocketServer;
