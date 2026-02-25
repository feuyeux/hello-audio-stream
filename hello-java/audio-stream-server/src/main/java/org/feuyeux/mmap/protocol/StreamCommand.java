package org.feuyeux.mmap.protocol;

/**
 * Stream lifecycle control commands
 */
public enum StreamCommand {
    CREATE,    // Create a new stream
    COMPLETE,  // Complete upload and mark as READY
    CLOSE      // Close/delete stream
}
