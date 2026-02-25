// Protocol command types and routing info

/**
 * @typedef {'STREAM' | 'DATA' | 'QUERY'} CommandType
 * @typedef {'CREATE' | 'COMPLETE' | 'CLOSE'} StreamCommand
 * @typedef {'READ'} DataCommand
 * @typedef {'GET_STATUS' | 'LIST_STREAMS'} QueryCommand
 *
 * @typedef {{ cmdType: CommandType, streamCmd?: StreamCommand, dataCmd?: DataCommand, queryCmd?: QueryCommand }} CommandInfo
 */

export {};
