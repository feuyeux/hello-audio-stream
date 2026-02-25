/** Protocol command types. */
export type CommandType = 'STREAM' | 'DATA' | 'QUERY';

/** Stream lifecycle commands (client→server). */
export type StreamCommand = 'CREATE' | 'COMPLETE' | 'CLOSE';

/** Data commands. */
export type DataCommand = 'READ';

/** Query commands. */
export type QueryCommand = 'GET_STATUS' | 'LIST_STREAMS';

/** Parsed command routing info. */
export interface CommandInfo {
  cmdType: CommandType;
  streamCmd?: StreamCommand;
  dataCmd?: DataCommand;
  queryCmd?: QueryCommand;
}
