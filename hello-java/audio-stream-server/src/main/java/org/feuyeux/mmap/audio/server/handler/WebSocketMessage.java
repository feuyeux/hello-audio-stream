package org.feuyeux.mmap.audio.server.handler;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * WebSocket message POJO for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class WebSocketMessage {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    @JsonProperty("type")
    private String type;

    @JsonProperty("streamId")
    private String streamId;

    @JsonProperty("offset")
    private Long offset;

    @JsonProperty("length")
    private Integer length;

    @JsonProperty("message")
    private String message;

    // Default constructor for Jackson
    public WebSocketMessage() {
    }

    // All-args constructor
    public WebSocketMessage(String type, String streamId, Long offset, Integer length, String message) {
        this.type = type;
        this.streamId = streamId;
        this.offset = offset;
        this.length = length;
        this.message = message;
    }

    // Factory methods for common message types
    public static WebSocketMessage started(String streamId, String message) {
        return new WebSocketMessage(MessageType.STARTED.getValue(), streamId, null, null, message);
    }

    public static WebSocketMessage stopped(String streamId, String message) {
        return new WebSocketMessage(MessageType.STOPPED.getValue(), streamId, null, null, message);
    }

    public static WebSocketMessage connected(String streamId, String message) {
        return new WebSocketMessage(MessageType.CONNECTED.getValue(), streamId, null, null, message);
    }

    public static WebSocketMessage error(String message) {
        return new WebSocketMessage(MessageType.ERROR.getValue(), null, null, null, message);
    }

    /**
     * Get the message type as enum.
     *
     * @return MessageType enum, or null if type is not a valid value
     */
    public MessageType getMessageTypeEnum() {
        return MessageType.fromString(type);
    }

    /**
     * Parse JSON string to WebSocketMessage.
     */
    public static WebSocketMessage fromJson(String json) throws JsonProcessingException {
        return MAPPER.readValue(json, WebSocketMessage.class);
    }

    /**
     * Convert WebSocketMessage to JSON string.
     */
    public String toJson() throws JsonProcessingException {
        return MAPPER.writeValueAsString(this);
    }

    // Getters and Setters
    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getStreamId() {
        return streamId;
    }

    public void setStreamId(String streamId) {
        this.streamId = streamId;
    }

    public Long getOffset() {
        return offset;
    }

    public void setOffset(Long offset) {
        this.offset = offset;
    }

    public Integer getLength() {
        return length;
    }

    public void setLength(Integer length) {
        this.length = length;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    @Override
    public String toString() {
        return "WebSocketMessage{" +
                "type='" + type + '\'' +
                ", streamId='" + streamId + '\'' +
                ", offset=" + offset +
                ", length=" + length +
                ", message='" + message + '\'' +
                '}';
    }
}
