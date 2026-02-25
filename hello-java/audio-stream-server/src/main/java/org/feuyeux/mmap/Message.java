package org.feuyeux.mmap;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.feuyeux.mmap.protocol.*;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record Message(
    @JsonProperty("command") String command,
    @JsonProperty("streamId") String streamId,
    @JsonProperty("offset") Long offset,
    @JsonProperty("length") Integer length,
    @JsonProperty("message") String msg,
    @JsonProperty("status") String status,
    @JsonProperty("size") Long size,
    @JsonProperty("streams") String streams
) {
    private static final ObjectMapper MAPPER = new ObjectMapper()
        .setSerializationInclusion(JsonInclude.Include.NON_NULL);

    public static Message parse(String json) throws Exception {
        return MAPPER.readValue(json, Message.class);
    }

    public String toJson() throws Exception {
        return MAPPER.writeValueAsString(this);
    }

    // Response messages
    public static Message connected(String id) {
        return new Message("CONNECTED", id, null, null, "Connected", null, null, null);
    }

    public static Message created(String id) {
        return new Message("CREATED", id, null, null, "Stream created", null, null, null);
    }

    public static Message completed(String id) {
        return new Message("COMPLETED", id, null, null, "Stream completed", null, null, null);
    }

    public static Message closed(String id) {
        return new Message("CLOSED", id, null, null, "Stream closed", null, null, null);
    }

    public static Message status(String id, String status, long size) {
        return new Message("STATUS", id, null, null, null, status, size, null);
    }

    public static Message streamList(java.util.List<String> ids) {
        return new Message("STREAM_LIST", null, null, null, null, null, null, String.join(",", ids));
    }

    public static Message error(String err) {
        return new Message("ERROR", null, null, null, err, null, null, null);
    }

    /**
     * Parse command type and specific command
     */
    public CommandInfo parseCommand() {
        if (command == null) return null;
        
        return switch (command.toUpperCase()) {
            // Stream commands
            case "CREATE", "START" -> new CommandInfo(CommandType.STREAM, StreamCommand.CREATE);
            case "COMPLETE", "STOP" -> new CommandInfo(CommandType.STREAM, StreamCommand.COMPLETE);
            case "CLOSE", "DELETE" -> new CommandInfo(CommandType.STREAM, StreamCommand.CLOSE);
            
            // Data commands
            case "READ", "GET" -> new CommandInfo(CommandType.DATA, DataCommand.READ);
            
            // Query commands
            case "GET_STATUS", "STATUS" -> new CommandInfo(CommandType.QUERY, QueryCommand.GET_STATUS);
            case "LIST_STREAMS", "LIST" -> new CommandInfo(CommandType.QUERY, QueryCommand.LIST_STREAMS);
            
            default -> null;
        };
    }

    public record CommandInfo(CommandType type, Object command) {
        public StreamCommand asStreamCommand() {
            return command instanceof StreamCommand ? (StreamCommand) command : null;
        }
        
        public DataCommand asDataCommand() {
            return command instanceof DataCommand ? (DataCommand) command : null;
        }
        
        public QueryCommand asQueryCommand() {
            return command instanceof QueryCommand ? (QueryCommand) command : null;
        }
    }
}
