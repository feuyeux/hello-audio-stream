/**
 * WebSocket client for communication with the server
 */

import WebSocket from "ws";
import { ControlMessage } from "./types";
import * as logger from "./logger";

export class WebSocketClient {
  private ws: WebSocket | null = null;
  private uri: string;
  private messageQueue: WebSocket.Data[] = [];
  private messageWaiters: Array<(data: WebSocket.Data) => void> = [];

  constructor(uri: string) {
    this.uri = uri;
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.uri);

      this.ws.on("open", () => {
        // Set up message handler
        this.ws!.on("message", (data: WebSocket.Data) => {
          if (this.messageWaiters.length > 0) {
            const waiter = this.messageWaiters.shift()!;
            waiter(data);
          } else {
            this.messageQueue.push(data);
          }
        });
        resolve();
      });

      this.ws.on("error", (error) => {
        reject(new Error(`WebSocket error: ${error.message}`));
      });
    });
  }

  async close(): Promise<void> {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  async sendText(message: string): Promise<void> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    return new Promise((resolve, reject) => {
      this.ws!.send(message, (error) => {
        if (error) {
          reject(new Error(`Failed to send text message: ${error.message}`));
        } else {
          resolve();
        }
      });
    });
  }

  async sendBinary(data: Buffer): Promise<void> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    return new Promise((resolve, reject) => {
      this.ws!.send(data, (error) => {
        if (error) {
          reject(new Error(`Failed to send binary message: ${error.message}`));
        } else {
          resolve();
        }
      });
    });
  }

  private async receiveMessage(): Promise<WebSocket.Data> {
    if (this.messageQueue.length > 0) {
      return this.messageQueue.shift()!;
    }

    return new Promise((resolve) => {
      this.messageWaiters.push(resolve);
    });
  }

  async receiveText(): Promise<string> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    const data = await this.receiveMessage();

    if (Buffer.isBuffer(data)) {
      // ws library sometimes delivers text messages as Buffer
      // Convert to string
      return data.toString("utf8");
    } else if (typeof data === "string") {
      return data;
    } else {
      return data.toString();
    }
  }

  async receiveBinary(): Promise<Buffer> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    const data = await this.receiveMessage();

    if (Buffer.isBuffer(data)) {
      return data;
    } else if (typeof data === "string") {
      // Check if it's an error message
      try {
        const msg: ControlMessage = JSON.parse(data);
        if (msg.type === "error") {
          throw new Error(`Server error: ${msg.message}`);
        } else {
          throw new Error(`Expected binary message, got text: ${data}`);
        }
      } catch (error) {
        if (
          error instanceof Error &&
          error.message.startsWith("Server error:")
        ) {
          throw error;
        }
        throw new Error(`Expected binary message, got text: ${data}`);
      }
    } else {
      return Buffer.from(data as ArrayBuffer);
    }
  }

  async sendControlMessage(msg: ControlMessage): Promise<void> {
    const jsonData = JSON.stringify(msg);
    logger.debug(`Sending control message: ${jsonData}`);
    await this.sendText(jsonData);
  }

  async receiveControlMessage(): Promise<ControlMessage> {
    const text = await this.receiveText();
    logger.debug(`Received control message: ${text}`);
    return JSON.parse(text) as ControlMessage;
  }
}
