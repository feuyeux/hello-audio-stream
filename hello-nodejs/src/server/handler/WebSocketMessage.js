/**
 * WebSocket message POJO for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */

const MessageType = require("./MessageType");

class WebSocketMessage {
  /**
   * Create a WebSocketMessage.
   *
   * @param {string} type - Message type
   * @param {string} streamId - Stream ID (optional)
   * @param {number} offset - Offset for GET requests (optional)
   * @param {number} length - Length for GET requests (optional)
   * @param {string} message - Additional message text (optional)
   */
  constructor(type, streamId = null, offset = null, length = null, message = null) {
    this.type = type;
    this.streamId = streamId;
    this.offset = offset;
    this.length = length;
    this.message = message;
  }

  /**
   * Factory method: Create a STARTED response message.
   *
   * @param {string} streamId - Stream ID
   * @param {string} message - Message text
   * @returns {WebSocketMessage}
   */
  static started(streamId, message = "Stream started successfully") {
    return new WebSocketMessage(MessageType.STARTED, streamId, null, null, message);
  }

  /**
   * Factory method: Create a STOPPED response message.
   *
   * @param {string} streamId - Stream ID
   * @param {string} message - Message text
   * @returns {WebSocketMessage}
   */
  static stopped(streamId, message = "Stream finalized successfully") {
    return new WebSocketMessage(MessageType.STOPPED, streamId, null, null, message);
  }

  /**
   * Factory method: Create a CONNECTED response message.
   *
   * @param {string} streamId - Connection ID
   * @param {string} message - Message text
   * @returns {WebSocketMessage}
   */
  static connected(streamId, message = "Connection established") {
    return new WebSocketMessage(MessageType.CONNECTED, streamId, null, null, message);
  }

  /**
   * Factory method: Create an ERROR response message.
   *
   * @param {string} message - Error message
   * @returns {WebSocketMessage}
   */
  static error(message) {
    return new WebSocketMessage(MessageType.ERROR, null, null, null, message);
  }

  /**
   * Get the message type as MessageType enum value.
   *
   * @returns {string|null} MessageType value, or null if type is not valid
   */
  getMessageType() {
    return MessageType.fromString(this.type);
  }

  /**
   * Parse JSON string to WebSocketMessage.
   *
   * @param {string} json - JSON string
   * @returns {WebSocketMessage}
   */
  static fromJson(json) {
    const data = JSON.parse(json);
    return new WebSocketMessage(
      data.type,
      data.streamId || null,
      data.offset || null,
      data.length || null,
      data.message || null
    );
  }

  /**
   * Convert WebSocketMessage to JSON string.
   * Excludes null values.
   *
   * @returns {string} JSON string
   */
  toJson() {
    const obj = {};
    if (this.type !== null) obj.type = this.type;
    if (this.streamId !== null) obj.streamId = this.streamId;
    if (this.offset !== null) obj.offset = this.offset;
    if (this.length !== null) obj.length = this.length;
    if (this.message !== null) obj.message = this.message;
    return JSON.stringify(obj);
  }

  /**
   * Convert to plain object (excluding null values).
   *
   * @returns {object}
   */
  toObject() {
    const obj = {};
    if (this.type !== null) obj.type = this.type;
    if (this.streamId !== null) obj.streamId = this.streamId;
    if (this.offset !== null) obj.offset = this.offset;
    if (this.length !== null) obj.length = this.length;
    if (this.message !== null) obj.message = this.message;
    return obj;
  }

  toString() {
    return `WebSocketMessage{type='${this.type}', streamId='${this.streamId}', offset=${this.offset}, length=${this.length}, message='${this.message}'}`;
  }
}

module.exports = WebSocketMessage;
