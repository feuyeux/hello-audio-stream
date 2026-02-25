// Per-connection handler.
import { parseCommand, connected, created, completed, closed, status, streamList, error } from './message.js';

export class Handler {
  #mgr;
  #connId;
  #streamId = null;
  #ws;

  constructor(mgr, connId, ws) {
    this.#mgr = mgr;
    this.#connId = connId;
    this.#ws = ws;
  }

  init() {
    this.#send(connected(this.#connId));
    this.#ws.on('message', (data, isBinary) => {
      if (isBinary) this.#handleBinary(data);
      else this.#handleText(data.toString());
    });
    this.#ws.on('close', () => this.#onClose());
    this.#ws.on('error', (e) => console.error(`[${this.#connId}] ws error:`, e));
  }

  #handleText(text) {
    try {
      const { msg, info } = parseCommand(text);
      if (info.cmdType === 'STREAM') this.#handleStreamCmd(info.streamCmd, msg);
      else if (info.cmdType === 'DATA') this.#handleDataCmd(msg);
      else this.#handleQueryCmd(info.queryCmd, msg);
    } catch (e) {
      this.#sendError(String(e));
    }
  }

  #handleBinary(data) {
    if (!this.#streamId) { this.#sendError('No active upload stream'); return; }
    try { this.#mgr.write(this.#streamId, data); }
    catch (e) { this.#sendError(String(e)); }
  }

  #handleStreamCmd(cmd, msg) {
    try {
      switch (cmd) {
        case 'CREATE':
          if (!msg.streamId) throw new Error('CREATE requires streamId');
          this.#mgr.create(msg.streamId);
          this.#streamId = msg.streamId;
          this.#send(created(msg.streamId));
          break;
        case 'COMPLETE': {
          const id = this.#streamId;
          if (!id) throw new Error('No active stream');
          this.#mgr.complete(id);
          this.#streamId = null;
          this.#send(completed(id));
          break;
        }
        case 'CLOSE':
          if (!msg.streamId) throw new Error('CLOSE requires streamId');
          this.#mgr.delete(msg.streamId);
          this.#send(closed(msg.streamId));
          break;
      }
    } catch (e) { this.#sendError(String(e)); }
  }

  #handleDataCmd(msg) {
    try {
      if (!msg.streamId) throw new Error('READ requires streamId');
      const data = this.#mgr.read(msg.streamId, msg.offset ?? 0, msg.length ?? 65536);
      if (data.length === 0) this.#sendError('No data at requested offset');
      else this.#ws.send(data);
    } catch (e) { this.#sendError(String(e)); }
  }

  #handleQueryCmd(cmd, msg) {
    try {
      if (cmd === 'GET_STATUS') {
        if (!msg.streamId) throw new Error('GET_STATUS requires streamId');
        const { status: st, size } = this.#mgr.statusOf(msg.streamId);
        this.#send(status(msg.streamId, st, size));
      } else {
        this.#send(streamList(this.#mgr.list()));
      }
    } catch (e) { this.#sendError(String(e)); }
  }

  #onClose() {
    if (this.#streamId) this.#mgr.markError(this.#streamId);
    console.error(`[${this.#connId}] disconnected`);
  }

  #send(msg) {
    if (this.#ws.readyState === 1 /* OPEN */) this.#ws.send(JSON.stringify(msg));
  }

  #sendError(message) {
    console.error(`[${this.#connId}] error: ${message}`);
    this.#send(error(message));
  }
}
