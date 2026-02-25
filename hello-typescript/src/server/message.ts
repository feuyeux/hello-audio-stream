import { CommandInfo } from './protocol';

/** Unified message DTO for both directions. */
export interface Message {
  command: string;
  streamId?: string;
  offset?: number;
  length?: number;
  message?: string;
  status?: string;
  size?: number;
  streams?: string;
}

// ── Factory helpers (server→client) ─────────────────────────────────────────

export const connected = (connId: string): Message =>
  ({ command: 'CONNECTED', streamId: connId });

export const created = (streamId: string): Message =>
  ({ command: 'CREATED', streamId });

export const completed = (streamId: string): Message =>
  ({ command: 'COMPLETED', streamId });

export const closed = (streamId: string): Message =>
  ({ command: 'CLOSED', streamId });

export const status = (streamId: string, st: string, size: number): Message =>
  ({ command: 'STATUS', streamId, status: st, size });

export const streamList = (streams: string): Message =>
  ({ command: 'STREAM_LIST', streams });

export const error = (message: string): Message =>
  ({ command: 'ERROR', message });

// ── Command parsing ──────────────────────────────────────────────────────────

/** Parse a JSON text frame into a Message + CommandInfo for routing. */
export function parseCommand(json: string): { msg: Message; info: CommandInfo } {
  let msg: Message;
  try {
    msg = JSON.parse(json) as Message;
  } catch {
    throw new Error('Invalid JSON');
  }

  switch (msg.command) {
    case 'CREATE':
      return { msg, info: { cmdType: 'STREAM', streamCmd: 'CREATE' } };
    case 'COMPLETE':
      return { msg, info: { cmdType: 'STREAM', streamCmd: 'COMPLETE' } };
    case 'CLOSE':
      return { msg, info: { cmdType: 'STREAM', streamCmd: 'CLOSE' } };
    case 'READ':
      return { msg, info: { cmdType: 'DATA', dataCmd: 'READ' } };
    case 'GET_STATUS':
      return { msg, info: { cmdType: 'QUERY', queryCmd: 'GET_STATUS' } };
    case 'LIST_STREAMS':
      return { msg, info: { cmdType: 'QUERY', queryCmd: 'LIST_STREAMS' } };
    default:
      throw new Error(`Unknown command: ${msg.command}`);
  }
}
