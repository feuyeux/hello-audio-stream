package org.feuyeux.mmap.client;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record Message(
    @JsonProperty("command") String command,
    @JsonProperty("streamId") String streamId,
    @JsonProperty("offset") Long offset,
    @JsonProperty("length") Integer length,
    @JsonProperty("message") String msg,
    @JsonProperty("status") String status,
    @JsonProperty("size") Long size
) {
    private static final ObjectMapper MAPPER = new ObjectMapper()
        .setSerializationInclusion(JsonInclude.Include.NON_NULL);

    public static Message parse(String json) throws Exception {
        return MAPPER.readValue(json, Message.class);
    }

    public String toJson() throws Exception {
        return MAPPER.writeValueAsString(this);
    }

    // Request messages
    public static Message create(String streamId) {
        return new Message("CREATE", streamId, null, null, null, null, null);
    }

    public static Message complete() {
        return new Message("COMPLETE", null, null, null, null, null, null);
    }

    public static Message read(long offset, int length) {
        return new Message("READ", null, offset, length, null, null, null);
    }

    public static Message close(String streamId) {
        return new Message("CLOSE", streamId, null, null, null, null, null);
    }
}
