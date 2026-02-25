package org.feuyeux.mmap.protocol;

/**
 * Top-level command type classification
 */
public enum CommandType {
    STREAM,    // Stream lifecycle commands
    DATA,      // Data operation commands
    QUERY      // Query commands
}
