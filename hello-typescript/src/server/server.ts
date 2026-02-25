import { WebSocketServer, WebSocket } from 'ws';
import { StreamManager } from './streamManager';
import { Handler } from './handler';

let connSeq = 0;

/** WebSocket server for audio streaming. */
export class Server {
  private readonly wss: WebSocketServer;
  private readonly mgr: StreamManager;
  private cleanupTimer: ReturnType<typeof setInterval> | null = null;

  constructor(port: number, cacheDir: string) {
    this.mgr = new StreamManager({ cacheDir });
    this.wss = new WebSocketServer({ port });
  }

  start(): void {
    this.wss.on('connection', (ws: WebSocket) => {
      const connId = `c-${connSeq++}`;
      const handler = new Handler(this.mgr, connId, ws);
      handler.init();
    });

    // Cleanup timer — every 30 seconds
    this.cleanupTimer = setInterval(() => this.mgr.cleanup(), 30_000);

    const addr = this.wss.address() as { port: number };
    console.log(`Server listening on ws://0.0.0.0:${addr.port}`);
  }

  stop(): void {
    if (this.cleanupTimer) clearInterval(this.cleanupTimer);
    this.wss.close();
  }
}

/** Entry point called from server.ts bin. */
export function run(port: number, cacheDir: string): void {
  const server = new Server(port, cacheDir);
  server.start();
  process.on('SIGINT', () => { server.stop(); process.exit(0); });
  process.on('SIGTERM', () => { server.stop(); process.exit(0); });
}
