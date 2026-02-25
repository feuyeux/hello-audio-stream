package server

/** Command type classification. */
enum class CommandType { STREAM, DATA, QUERY }

/** Stream lifecycle commands. */
enum class StreamCommand { CREATE, COMPLETE, CLOSE }

/** Data transfer commands. */
enum class DataCommand { READ }

/** Query commands. */
enum class QueryCommand { GET_STATUS, LIST_STREAMS }

/** Parsed command information. */
data class CommandInfo(
    val cmdType: CommandType,
    val streamCmd: StreamCommand? = null,
    val dataCmd: DataCommand? = null,
    val queryCmd: QueryCommand? = null,
) {
    companion object {
        private val map = mapOf(
            "CREATE"       to CommandInfo(CommandType.STREAM, streamCmd = StreamCommand.CREATE),
            "COMPLETE"     to CommandInfo(CommandType.STREAM, streamCmd = StreamCommand.COMPLETE),
            "CLOSE"        to CommandInfo(CommandType.STREAM, streamCmd = StreamCommand.CLOSE),
            "READ"         to CommandInfo(CommandType.DATA, dataCmd = DataCommand.READ),
            "GET_STATUS"   to CommandInfo(CommandType.QUERY, queryCmd = QueryCommand.GET_STATUS),
            "LIST_STREAMS" to CommandInfo(CommandType.QUERY, queryCmd = QueryCommand.LIST_STREAMS),
        )

        fun lookup(command: String): CommandInfo =
            map[command] ?: throw IllegalArgumentException("Unknown command: $command")
    }
}
