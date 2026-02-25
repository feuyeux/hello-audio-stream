// Audio stream client.
import * as fs from 'fs';
import * as crypto from 'crypto';
import * as path from 'path';
import WebSocket from 'ws';

const CHUNK_SIZE = 64 * 1024;

export class Client {
  #ws;

  constructor(ws) { this.#ws = ws; }

  static async connect(serverUri) {
    const ws = new WebSocket(serverUri);
    await new Promise((resolve, reject) => {
      ws.once('open', resolve);
      ws.once('error', reject);
    });
    const client = new Client(ws);
    const m = await client.#recvJson();
    if (m.command !== 'CONNECTED') throw new Error(`Expected CONNECTED, got: ${m.command}`);
    console.log(`Connected (conn_id=${m.streamId ?? '?'})`);
    return client;
  }

  async upload(filePath, streamId) {
    this.#sendJson({ command: 'CREATE', streamId });
    const r1 = await this.#recvJson();
    if (r1.command !== 'CREATED') throw new Error(`Expected CREATED, got ${r1.command}: ${r1.message}`);

    const fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(CHUNK_SIZE);
    let n;
    do {
      n = fs.readSync(fd, buf, 0, CHUNK_SIZE, null);
      if (n > 0) await new Promise((res, rej) => this.#ws.send(buf.slice(0, n), e => e ? rej(e) : res()));
    } while (n === CHUNK_SIZE);
    fs.closeSync(fd);

    this.#sendJson({ command: 'COMPLETE' });
    const r2 = await this.#recvJson();
    if (r2.command !== 'COMPLETED') throw new Error(`Expected COMPLETED, got ${r2.command}: ${r2.message}`);
    console.log(`Upload complete: ${streamId}`);
  }

  async download(streamId, outputPath) {
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const out = fs.openSync(outputPath, 'w');
    let offset = 0;

    while (true) {
      this.#sendJson({ command: 'READ', streamId, offset, length: CHUNK_SIZE });
      const frame = await this.#recvFrame();
      if (Buffer.isBuffer(frame)) {
        if (frame.length === 0) break;
        fs.writeSync(out, frame);
        offset += frame.length;
      } else {
        const m = JSON.parse(frame);
        if (m.command === 'ERROR') break;
        throw new Error(`Unexpected text during download: ${m.command}`);
      }
    }
    fs.closeSync(out);
    console.log(`Download complete: ${streamId} (${offset} bytes)`);
    return offset;
  }

  static verify(pathA, pathB) {
    const hash = (p) => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
    const ok = hash(pathA) === hash(pathB);
    if (ok) console.log('Verification OK: files match');
    else console.error('Verification FAILED: files differ');
    return ok;
  }

  close() { this.#ws.close(); }

  #sendJson(m) { this.#ws.send(JSON.stringify(m)); }

  #recvJson() {
    return new Promise((resolve, reject) => {
      const handler = (data, isBinary) => {
        if (!isBinary) {
          this.#ws.off('message', handler);
          resolve(JSON.parse(data.toString()));
        }
      };
      this.#ws.once('error', reject);
      this.#ws.on('message', handler);
    });
  }

  #recvFrame() {
    return new Promise((resolve, reject) => {
      this.#ws.once('message', (data, isBinary) => resolve(isBinary ? data : data.toString()));
      this.#ws.once('error', reject);
    });
  }
}

/** Entry point */
export async function run(server, inputPath, outputPath) {
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
  console.log(`Upload: ${uploadMs}ms`);

  await new Promise(r => setTimeout(r, 1000));

  console.log('[2/3] Downloading...');
  const t1 = Date.now();
  const downloaded = await client.download(streamId, outputPath);
  const dlMs = Date.now() - t1;
  console.log(`Download: ${dlMs}ms`);

  console.log('[3/3] Verifying...');
  const ok = Client.verify(inputPath, outputPath);
  console.log(`Result: ${ok ? 'SUCCESS' : 'FAILED'}`);
  client.close();
}
