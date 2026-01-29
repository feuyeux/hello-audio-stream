/**
 * WebSocket message types enum.
 * All type values are uppercase as per protocol specification.
 */
export const MessageType = {
  START: "START",
  STARTED: "STARTED",
  STOP: "STOP",
  STOPPED: "STOPPED",
  GET: "GET",
  ERROR: "ERROR",
  CONNECTED: "CONNECTED",
};

/**
 * Parse string to MessageType value.
 * Case-insensitive comparison for backward compatibility.
 * @param {string|null} value - String value to parse
 * @returns {string|null} - Corresponding MessageType value or null
 */
export const getMessageType = (value) => {
  if (!value) return null;
  const upperValue = value.toUpperCase();
  return Object.values(MessageType).find((type) => type === upperValue) || null;
};

/**
 * WebSocket message class for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */
export class WebSocketMessage {
  /**
   * @param {string} type - Message type (START, STOP, GET, STARTED, STOPPED, ERROR)
   * @param {string|null} streamId - Stream identifier
   * @param {number|null} offset - Read offset for GET messages
   * @param {number|null} length - Read length for GET messages
   * @param {string|null} message - Response message
   */
  constructor(
    type,
    streamId = null,
    offset = null,
    length = null,
    message = null,
  ) {
    this.type = type;
    this.streamId = streamId;
    this.offset = offset;
    this.length = length;
    this.message = message;
  }

  /**
   * Convert to JSON string, excluding null values.
   * @returns {string}
   */
  toJSON() {
    const obj = { type: this.type };
    if (this.streamId !== null) obj.streamId = this.streamId;
    if (this.offset !== null) obj.offset = this.offset;
    if (this.length !== null) obj.length = this.length;
    if (this.message !== null) obj.message = this.message;
    return JSON.stringify(obj);
  }

  /**
   * Parse from JSON string.
   * @param {string} jsonStr
   * @returns {WebSocketMessage}
   */
  static fromJSON(jsonStr) {
    const data = JSON.parse(jsonStr);
    return WebSocketMessage.fromObject(data);
  }

  /**
   * Parse from object.
   * @param {object} data
   * @returns {WebSocketMessage}
   */
  static fromObject(data) {
    return new WebSocketMessage(
      data.type || "",
      data.streamId || null,
      data.offset !== undefined ? data.offset : null,
      data.length !== undefined ? data.length : null,
      data.message || null,
    );
  }

  /**
   * Create a STARTED response message.
   * @param {string} streamId
   * @param {string} message
   * @returns {WebSocketMessage}
   */
  static started(streamId, message = "Stream started successfully") {
    return new WebSocketMessage("STARTED", streamId, null, null, message);
  }

  /**
   * Create a STOPPED response message.
   * @param {string} streamId
   * @param {string} message
   * @returns {WebSocketMessage}
   */
  static stopped(streamId, message = "Stream finalized successfully") {
    return new WebSocketMessage("STOPPED", streamId, null, null, message);
  }

  /**
   * Create an ERROR response message.
   * @param {string} message
   * @returns {WebSocketMessage}
   */
  static error(message) {
    return new WebSocketMessage("ERROR", null, null, null, message);
  }
}
