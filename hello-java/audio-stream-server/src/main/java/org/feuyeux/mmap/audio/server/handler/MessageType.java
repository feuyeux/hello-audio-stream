package org.feuyeux.mmap.audio.server.handler;

/**
 * WebSocket message types enum.
 * All type values are uppercase as per protocol specification.
 */
public enum MessageType {
    START,
    STARTED,
    STOP,
    STOPPED,
    GET,
    ERROR,
    CONNECTED;

    /**
     * Get the uppercase string value for this enum.
     *
     * @return uppercase string representation
     */
    public String getValue() {
        return name();
    }

    /**
     * Parse string to MessageType enum.
     * Case-insensitive comparison for backward compatibility.
     *
     * @param value string value to parse
     * @return corresponding MessageType, or null if not found
     */
    public static MessageType fromString(String value) {
        if (value == null) {
            return null;
        }
        try {
            return MessageType.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }
}
