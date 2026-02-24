package org.feuyeux.mmap;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;

public record Message(
    @JsonProperty("type") String type,
    @JsonProperty("streamId") String streamId,
    @JsonProperty("offset") Long offset,
    @JsonProperty("length") Integer length,
    @JsonProperty("message") String msg
) {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static Message parse(String json) throws Exception {
        return MAPPER.readValue(json, Message.class);
    }

    public String toJson() throws Exception {
        return MAPPER.writeValueAsString(this);
    }

    public static Message connected(String id) {
        return new Message("CONNECTED", id, null, null, "Connected");
    }

    public static Message started(String id) {
        return new Message("STARTED", id, null, null, "Started");
    }

    public static Message stopped(String id) {
        return new Message("STOPPED", id, null, null, "Stopped");
    }

    public static Message error(String err) {
        return new Message("ERROR", null, null, null, err);
    }

    public Type typeEnum() {
        if (type == null) return null;
        return switch (type.toUpperCase()) {
            case "START" -> Type.START;
            case "STOP" -> Type.STOP;
            case "GET" -> Type.GET;
            default -> null;
        };
    }

    public enum Type { START, STOP, GET }
}
