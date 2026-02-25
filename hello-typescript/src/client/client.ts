import * as fs from 'fs';
import * as crypto from 'crypto';
import * as path from 'path';
import WebSocket from 'ws';

import { Message } from '../server/message';

const CHUNK_SIZE = 64 * 1024; // 64 KB

/** Client for the audio stream cache server. */
export class Client {
  private ws: WebSocket;

  private constructor(ws: WebSocket) {
    this.ws = ws;
  }

  /** Connect and wait for CONNECTED. */
  static async connect(serverUri: string): Promise<Client> {
    const ws = new WebSocket(serverUri);
    await new Promise<void>((resolve, reject) => {
      ws.once('open', resolve);
      ws.once('error', reject);
    });
    const client = new Client(ws);
    const m = await client.recvJson();
    if (m.command !== 'CONNECTED') {
      throw new Error(`Expected CONNECTED, got: ${m.command}`);
    }
    console.log(`Connected (conn_id=${m.streamId ?? '?'})`);
    return client;
  }

  /** Upload a local file. */
  async upload(filePath: string, streamId: string): Promise<void> {
    // CREATE
    this.sendJson({ command: 'CREATE', streamId });
    const r1 = await this.recvJson();
    if (r1.command !== 'CREATED') {
      throw new Error(`Expected CREATED, got ${r1.command}: ${r1.message}`);
    }

    // Binary chunks
    const fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(CHUNK_SIZE);
    let bytesRead: number;
    do {
      bytesRead = fs.readSync(fd, buf, 0, CHUNK_SIZE, null);
      if (bytesRead > 0) {
        await new Promise<void>((resolve, reject) => {
          this.ws.send(buf.slice(0, bytesRead), (err) => err ? reject(err) : resolve());
        });
      }
    } while (bytesRead === CHUNK_SIZE);
    fs.closeSync(fd);

    // COMPLETE
    this.sendJson({ command: 'COMPLETE' });
    const r2 = await this.recvJson();
    if (r2.command !== 'COMPLETED') {
      throw new Error(`Expected COMPLETED, got ${r2.command}: ${r2.message}`);
    }
    console.log(`Upload complete: ${streamId}`);
  }

  /** Download a stream to a local file. */
  async download(streamId: string, outputPath: string): Promise<number> {
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

    let offset = 0;
    const out = fs.openSync(outputPath, 'w');

    while (true) {
      this.sendJson({ command: 'READ', streamId, offset, length: CHUNK_SIZE });
      const frame = await this.recvFrame();

      if (Buffer.isBuffer(frame)) {
        if ((frame as Buffer).length === 0) break;
        fs.writeSync(out, frame as Buffer);
        offset += (frame as Buffer).length;
      } else {
        // text frame
        const m = JSON.parse(frame as string) as Message;
        if (m.command === 'ERROR') break; // end or error
        throw new Error(`Unexpected text during download: ${m.command}`);
      }
    }
    fs.closeSync(out);
    console.log(`Download complete: ${streamId} (${offset} bytes)`);
    return offset;
  }

  /** Verify two files match via SHA-256. */
  static verify(pathA: string, pathB: string): boolean {
    const hash = (p: string) => {
      const h = crypto.createHash('sha256');
      h.update(fs.readFileSync(p));
      return h.digest('hex');
    };
    const ok = hash(pathA) === hash(pathB);
    if (ok) console.log('Verification OK: files match');
    else console.error('Verification FAILED: files differ');
    return ok;
  }

  close(): void {
    this.ws.close();
  }

  private sendJson(m: Message): void {
    this.ws.send(JSON.stringify(m));
  }

  private recvJson(): Promise<Message> {
    return new Promise((resolve, reject) => {
      const onMsg = (data: Buffer | string, isBinary: boolean) => {
        if (!isBinary) {
          this.ws.off('message', onMsg);
          resolve(JSON.parse(data.toString()) as Message);
        }
      };
      this.ws.once('error', reject);
      this.ws.on('message', onMsg);
    });
  }

  private recvFrame(): Promise<Buffer | string> {
    return new Promise((resolve, reject) => {
      this.ws.once('message', (data: Buffer | string, isBinary: boolean) => {
        resolve(isBinary ? (data as Buffer) : data.toString());
      });
      this.ws.once('error', reject);
    });
  }
}

/** Entry point called from client.ts bin. */
export async function run(
  server: string,
  inputPath: string,
  outputPath: string,
): Promise<void> {
  console.log('========================================');
  console.log('Starting Audio Stream Client');
  console.log(`Input:  ${inputPath}`);
  console.log(`Output: ${outputPath}`);
  console.log('========================================');

  const streamId = `stream-${Math.floor(Math.random() * 0xffffffff)}`;
  const client = await Client.connect(server);
  const fileSize = fs.statSync(inputPath).size;
  console.log(`File size: ${fileSize} bytes`);

  console.log('[1/3] Uploading...');
  const t0 = Date.now();
  await client.upload(inputPath, streamId);
  const uploadMs = Date.now() - t0;
  console.log(`Upload: ${uploadMs}ms (${mbps(fileSize, uploadMs).toFixed(2)} Mbps)`);

  await new Promise((r) => setTimeout(r, 1000));

  console.log('[2/3] Downloading...');
  const t1 = Date.now();
  const downloaded = await client.download(streamId, outputPath);
  const dlMs = Date.now() - t1;
  console.log(`Download: ${dlMs}ms (${mbps(downloaded, dlMs).toFixed(2)} Mbps)`);

  console.log('[3/3] Verifying...');
  const ok = Client.verify(inputPath, outputPath);
  console.log(`Result: ${ok ? 'SUCCESS' : 'FAILED'}`);
  client.close();
}

function mbps(bytes: number, ms: number): number {
  if (ms === 0) return 0;
  return (bytes * 8) / (ms * 1000);
}
