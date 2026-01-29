/**
 * WebSocket message class for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */

/**
 * WebSocket message types enum.
 * All type values are uppercase as per protocol specification.
 */
export enum MessageType {
  START = "START",
  STARTED = "STARTED",
  STOP = "STOP",
  STOPPED = "STOPPED",
  GET = "GET",
  ERROR = "ERROR",
  CONNECTED = "CONNECTED",
}

/**
 * Parse string to MessageType enum.
 * Case-insensitive comparison for backward compatibility.
 */
export function getMessageType(
  value: string | undefined,
): MessageType | undefined {
  if (!value) return undefined;
  const upperValue = value.toUpperCase();
  return Object.values(MessageType).find((type) => type === upperValue);
}

export interface IWebSocketMessage {
  type: string;
  streamId?: string;
  offset?: number;
  length?: number;
  message?: string;
}

export class WebSocketMessage implements IWebSocketMessage {
  type: string;
  streamId?: string;
  offset?: number;
  length?: number;
  message?: string;

  constructor(
    type: string,
    streamId?: string,
    offset?: number,
    length?: number,
    message?: string,
  ) {
    this.type = type;
    this.streamId = streamId;
    this.offset = offset;
    this.length = length;
    this.message = message;
  }

  /**
   * Convert to JSON string, excluding undefined values.
   */
  toJSON(): string {
    const obj: IWebSocketMessage = { type: this.type };
    if (this.streamId !== undefined) obj.streamId = this.streamId;
    if (this.offset !== undefined) obj.offset = this.offset;
    if (this.length !== undefined) obj.length = this.length;
    if (this.message !== undefined) obj.message = this.message;
    return JSON.stringify(obj);
  }

  /**
   * Parse from JSON string.
   */
  static fromJSON(jsonStr: string): WebSocketMessage {
    const data = JSON.parse(jsonStr);
    return WebSocketMessage.fromObject(data);
  }

  /**
   * Parse from object.
   */
  static fromObject(data: IWebSocketMessage): WebSocketMessage {
    return new WebSocketMessage(
      data.type || "",
      data.streamId,
      data.offset,
      data.length,
      data.message,
    );
  }

  /**
   * Create a STARTED response message.
   */
  static started(
    streamId: string,
    message: string = "Stream started successfully",
  ): WebSocketMessage {
    return new WebSocketMessage(
      "STARTED",
      streamId,
      undefined,
      undefined,
      message,
    );
  }

  /**
   * Create a STOPPED response message.
   */
  static stopped(
    streamId: string,
    message: string = "Stream finalized successfully",
  ): WebSocketMessage {
    return new WebSocketMessage(
      "STOPPED",
      streamId,
      undefined,
      undefined,
      message,
    );
  }

  /**
   * Create an ERROR response message.
   */
  static error(message: string): WebSocketMessage {
    return new WebSocketMessage(
      "ERROR",
      undefined,
      undefined,
      undefined,
      message,
    );
  }
}
