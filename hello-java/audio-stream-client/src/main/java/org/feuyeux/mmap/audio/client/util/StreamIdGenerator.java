package org.feuyeux.mmap.audio.client.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Stream ID generator for creating unique stream identifiers.
 * Matches the C++ StreamIdGenerator interface.
 */
public class StreamIdGenerator {
    private static final Logger logger = LoggerFactory.getLogger(StreamIdGenerator.class);
    private static final String DEFAULT_PREFIX = "stream";
    private static final Pattern STREAM_ID_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$");

    /**
     * Generate a unique stream ID with default prefix "stream".
     *
     * @return stream ID in format "stream-{uuid}"
     */
    public String generate() {
        return generateWithPrefix(DEFAULT_PREFIX);
    }

    /**
     * Generate a unique stream ID with custom prefix.
     *
     * @param prefix prefix for the stream ID
     * @return stream ID in format "{prefix}-{uuid}"
     */
    public String generateWithPrefix(String prefix) {
        if (prefix == null || prefix.isEmpty()) {
            prefix = DEFAULT_PREFIX;
        }
        
        String uuid = UUID.randomUUID().toString();
        String streamId = prefix + "-" + uuid;
        
        logger.debug("Generated stream ID: {}", streamId);
        return streamId;
    }

    /**
     * Generate a short stream ID (8 characters).
     *
     * @return short stream ID in format "stream-{short-uuid}"
     */
    public String generateShort() {
        return generateShortWithPrefix(DEFAULT_PREFIX);
    }

    /**
     * Generate a short stream ID with custom prefix.
     *
     * @param prefix prefix for the stream ID
     * @return short stream ID in format "{prefix}-{short-uuid}"
     */
    public String generateShortWithPrefix(String prefix) {
        if (prefix == null || prefix.isEmpty()) {
            prefix = DEFAULT_PREFIX;
        }
        
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        String streamId = prefix + "-" + uuid;
        
        logger.debug("Generated short stream ID: {}", streamId);
        return streamId;
    }

    /**
     * Validate a stream ID format.
     *
     * @param streamId stream ID to validate
     * @return true if valid format
     */
    public boolean validate(String streamId) {
        if (streamId == null || streamId.isEmpty()) {
            logger.warn("Stream ID is null or empty");
            return false;
        }
        
        // Check if it matches the expected pattern
        boolean isValid = STREAM_ID_PATTERN.matcher(streamId).matches();
        
        if (!isValid) {
            logger.warn("Invalid stream ID format: {}", streamId);
        }
        
        return isValid;
    }

    /**
     * Validate a short stream ID format.
     *
     * @param streamId stream ID to validate
     * @return true if valid short format
     */
    public boolean validateShort(String streamId) {
        if (streamId == null || streamId.isEmpty()) {
            logger.warn("Stream ID is null or empty");
            return false;
        }
        
        // Check if it matches the short pattern: prefix-8chars
        Pattern shortPattern = Pattern.compile("^[a-zA-Z0-9_-]+-[a-f0-9]{8}$");
        boolean isValid = shortPattern.matcher(streamId).matches();
        
        if (!isValid) {
            logger.warn("Invalid short stream ID format: {}", streamId);
        }
        
        return isValid;
    }

    /**
     * Extract the prefix from a stream ID.
     *
     * @param streamId stream ID
     * @return prefix, or null if invalid format
     */
    public String extractPrefix(String streamId) {
        if (streamId == null || streamId.isEmpty()) {
            return null;
        }
        
        int dashIndex = streamId.indexOf('-');
        if (dashIndex > 0) {
            return streamId.substring(0, dashIndex);
        }
        
        return null;
    }

    /**
     * Extract the UUID part from a stream ID.
     *
     * @param streamId stream ID
     * @return UUID string, or null if invalid format
     */
    public String extractUuid(String streamId) {
        if (streamId == null || streamId.isEmpty()) {
            return null;
        }
        
        int dashIndex = streamId.indexOf('-');
        if (dashIndex > 0 && dashIndex < streamId.length() - 1) {
            return streamId.substring(dashIndex + 1);
        }
        
        return null;
    }
}
