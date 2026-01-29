/**
 * WebSocket client for communication with the server
 */

import WebSocket from "ws";

export class WebSocketClient {
  constructor(uri) {
    this.ws = null;
    this.uri = uri;
    this.messageQueue = [];
    this.messageWaiters = [];
  }

  async connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.uri);

      this.ws.on("open", () => {
        this.ws.on("message", (data) => {
          if (this.messageWaiters.length > 0) {
            const waiter = this.messageWaiters.shift();
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

  async close() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  async sendText(message) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    return new Promise((resolve, reject) => {
      this.ws.send(message, (error) => {
        if (error) {
          reject(new Error(`Failed to send text message: ${error.message}`));
        } else {
          resolve();
        }
      });
    });
  }

  async sendBinary(data) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    return new Promise((resolve, reject) => {
      this.ws.send(data, (error) => {
        if (error) {
          reject(new Error(`Failed to send binary message: ${error.message}`));
        } else {
          resolve();
        }
      });
    });
  }

  async receiveMessage() {
    if (this.messageQueue.length > 0) {
      return this.messageQueue.shift();
    }

    return new Promise((resolve) => {
      this.messageWaiters.push(resolve);
    });
  }

  async receiveText() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    const data = await this.receiveMessage();

    if (Buffer.isBuffer(data)) {
      return data.toString("utf8");
    } else if (typeof data === "string") {
      return data;
    } else {
      return data.toString();
    }
  }

  async receiveBinary() {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket is not connected");
    }

    const data = await this.receiveMessage();

    if (Buffer.isBuffer(data)) {
      return data;
    } else if (typeof data === "string") {
      try {
        const msg = JSON.parse(data);
        if (msg.type === "ERROR") {
          throw new Error(`Server error: ${msg.message}`);
        } else {
          throw new Error(`Expected binary message, got text: ${data}`);
        }
      } catch (error) {
        if (error.message.startsWith("Server error:")) {
          throw error;
        }
        throw new Error(`Expected binary message, got text: ${data}`);
      }
    } else {
      return Buffer.from(data);
    }
  }

  async sendControlMessage(msg) {
    const jsonData = JSON.stringify(msg);
    await this.sendText(jsonData);
  }

  async receiveControlMessage() {
    const text = await this.receiveText();
    return JSON.parse(text);
  }
}
