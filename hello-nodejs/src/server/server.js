// WebSocket server for audio streaming.
import { WebSocketServer } from 'ws';
import { StreamManager } from './streamManager.js';
import { Handler } from './handler.js';

let connSeq = 0;

export class Server {
  #wss;
  #mgr;
  #cleanupTimer = null;

  constructor(port, cacheDir) {
    this.#mgr = new StreamManager({ cacheDir });
    this.#wss = new WebSocketServer({ port });
  }

  start() {
    this.#wss.on('connection', (ws) => {
      const connId = `c-${connSeq++}`;
      const handler = new Handler(this.#mgr, connId, ws);
      handler.init();
    });
    this.#cleanupTimer = setInterval(() => this.#mgr.cleanup(), 30_000);
    console.log(`Server listening on ws://0.0.0.0:${this.#wss.address().port}`);
  }

  stop() {
    if (this.#cleanupTimer) clearInterval(this.#cleanupTimer);
    this.#wss.close();
  }
}

/** Entry point */
export function run(port, cacheDir) {
  const server = new Server(port, cacheDir);
  server.start();
  process.on('SIGINT', () => { server.stop(); process.exit(0); });
  process.on('SIGTERM', () => { server.stop(); process.exit(0); });
}
