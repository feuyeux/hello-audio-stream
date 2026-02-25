import WebSocket from 'ws';
import { StreamManager } from './streamManager';
import { parseCommand } from './message';
import * as msg from './message';

/** Per-connection handler. */
export class Handler {
  private connId: string;
  private streamId: string | null = null;

  constructor(
    private readonly mgr: StreamManager,
    connId: string,
    private readonly ws: WebSocket,
  ) {
    this.connId = connId;
  }

  /** Send CONNECTED and attach event listeners. */
  init(): void {
    this.send(msg.connected(this.connId));

    this.ws.on('message', (data: Buffer | string, isBinary: boolean) => {
      if (isBinary) {
        this.handleBinary(data as Buffer);
      } else {
        this.handleText(data.toString());
      }
    });

    this.ws.on('close', () => this.onClose());
    this.ws.on('error', (err) => console.error(`[${this.connId}] error:`, err));
  }

  private handleText(text: string): void {
    try {
      const { msg: m, info } = parseCommand(text);
      if (info.cmdType === 'STREAM') {
        this.handleStreamCmd(info.streamCmd!, m);
      } else if (info.cmdType === 'DATA') {
        this.handleDataCmd(m);
      } else {
        this.handleQueryCmd(info.queryCmd!, m);
      }
    } catch (e) {
      this.sendError(String(e));
    }
  }

  private handleBinary(data: Buffer): void {
    if (!this.streamId) {
      this.sendError('No active upload stream');
      return;
    }
    try {
      this.mgr.write(this.streamId, data);
    } catch (e) {
      this.sendError(String(e));
    }
  }

  private handleStreamCmd(cmd: msg.Message['command'], m: msg.Message): void {
    try {
      switch (cmd) {
        case 'CREATE': {
          if (!m.streamId) throw new Error('CREATE requires streamId');
          this.mgr.create(m.streamId);
          this.streamId = m.streamId;
          this.send(msg.created(m.streamId));
          break;
        }
        case 'COMPLETE': {
          const id = this.streamId;
          if (!id) throw new Error('No active stream');
          this.mgr.complete(id);
          this.streamId = null;
          this.send(msg.completed(id));
          break;
        }
        case 'CLOSE': {
          if (!m.streamId) throw new Error('CLOSE requires streamId');
          this.mgr.delete(m.streamId);
          this.send(msg.closed(m.streamId));
          break;
        }
      }
    } catch (e) {
      this.sendError(String(e));
    }
  }

  private handleDataCmd(m: msg.Message): void {
    try {
      if (!m.streamId) throw new Error('READ requires streamId');
      const data = this.mgr.read(m.streamId, m.offset ?? 0, m.length ?? 65536);
      if (data.length === 0) {
        this.sendError('No data at requested offset');
      } else {
        this.ws.send(data);
      }
    } catch (e) {
      this.sendError(String(e));
    }
  }

  private handleQueryCmd(cmd: string, m: msg.Message): void {
    try {
      if (cmd === 'GET_STATUS') {
        if (!m.streamId) throw new Error('GET_STATUS requires streamId');
        const { status, size } = this.mgr.statusOf(m.streamId);
        this.send(msg.status(m.streamId, status, size));
      } else {
        this.send(msg.streamList(this.mgr.list()));
      }
    } catch (e) {
      this.sendError(String(e));
    }
  }

  private onClose(): void {
    if (this.streamId) {
      this.mgr.markError(this.streamId);
    }
    console.error(`[${this.connId}] disconnected`);
  }

  private send(m: msg.Message): void {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(m));
    }
  }

  private sendError(message: string): void {
    console.error(`[${this.connId}] error: ${message}`);
    this.send(msg.error(message));
  }
}
