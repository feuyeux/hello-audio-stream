// Message DTO factory helpers and command parser.

/** @returns {{ command: string, streamId: string }} */
export const connected = (connId) => ({ command: 'CONNECTED', streamId: connId });

/** @returns {{ command: string, streamId: string }} */
export const created = (streamId) => ({ command: 'CREATED', streamId });

/** @returns {{ command: string, streamId: string }} */
export const completed = (streamId) => ({ command: 'COMPLETED', streamId });

/** @returns {{ command: string, streamId: string }} */
export const closed = (streamId) => ({ command: 'CLOSED', streamId });

/** @returns {{ command: string, streamId: string, status: string, size: number }} */
export const status = (streamId, st, size) => ({ command: 'STATUS', streamId, status: st, size });

/** @returns {{ command: string, streams: string }} */
export const streamList = (streams) => ({ command: 'STREAM_LIST', streams });

/** @returns {{ command: string, message: string }} */
export const error = (message) => ({ command: 'ERROR', message });

/**
 * Parse a JSON text frame into msg + commandInfo.
 * @param {string} json
 * @returns {{ msg: object, info: import('./protocol.js').CommandInfo }}
 */
export function parseCommand(json) {
  let msg;
  try {
    msg = JSON.parse(json);
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
