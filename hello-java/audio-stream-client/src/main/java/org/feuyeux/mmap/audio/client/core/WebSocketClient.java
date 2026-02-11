package org.feuyeux.mmap.audio.client.core;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.nio.ByteBuffer;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * WebSocket client for generic message communication.
 * Handles connection management, message sending/receiving, and connection lifecycle.
 * Thread-safe design with proper connection state management.
 * <p>
 * This class wraps the Java-WebSocket library client to provide a unified interface
 * matching the C++ WebSocketClient implementation.
 */
public class WebSocketClient implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(WebSocketClient.class);

    private org.java_websocket.client.WebSocketClient internalClient;
    private final URI serverUri;
    private volatile CountDownLatch connectLatch;
    private final AtomicReference<String> connectionId = new AtomicReference<>();
    private final BlockingQueue<byte[]> binaryMessageQueue = new LinkedBlockingQueue<>();
    private final BlockingQueue<String> textMessageQueue = new LinkedBlockingQueue<>();
    private volatile boolean connected = false;

    public WebSocketClient(URI serverUri) {
        this.serverUri = serverUri;
        this.connectLatch = new CountDownLatch(1);
        createInternalClient();
    }

    /**
     * Create a new internal WebSocket client with callbacks.
     */
    private void createInternalClient() {
        this.internalClient = new org.java_websocket.client.WebSocketClient(serverUri) {
            @Override
            public void onOpen(org.java_websocket.handshake.ServerHandshake handshake) {
                logger.info("Connected to WebSocket server: {}", getURI());
                connected = true;
                connectLatch.countDown();
            }

            @Override
            public void onMessage(String message) {
                logger.debug("Received text message: {}", message);

                // Handle CONNECTED message
                if (message.contains("\"type\":\"CONNECTED\"") || message.contains("\"type\":\"connected\"")) {
                    logger.info("Received CONNECTED message from server");
                    int idIndex = message.indexOf("\"streamId\":\"");
                    if (idIndex != -1) {
                        int start = idIndex + 12;
                        int end = message.indexOf("\"", start);
                        connectionId.set(message.substring(start, end));
                        logger.info("Connection ID: {}", connectionId.get());
                    }
                }

                // Queue message for polling
                if (!textMessageQueue.offer(message)) {
                    logger.warn("Text message queue full, message dropped");
                }

            }

            @Override
            public void onMessage(ByteBuffer bytes) {
                byte[] data = new byte[bytes.remaining()];
                bytes.get(data);
                logger.debug("Received binary data: {} bytes", data.length);

                // Queue message for polling
                if (!binaryMessageQueue.offer(data)) {
                    logger.warn("Binary message queue full, message dropped");
                }

            }

            @Override
            public void onClose(int code, String reason, boolean remote) {
                logger.info("Connection closed - Code: {}, Reason: {}, Remote: {}", code, reason, remote);
                connected = false;
            }

            @Override
            public void onError(Exception ex) {
                logger.error("WebSocket error", ex);
                connected = false;

            }
        };
    }

    /**
     * Connect to server with retry logic.
     * Creates a new internal WebSocket client for each retry attempt.
     *
     * @param maxRetries maximum number of retry attempts
     * @return true if connection established successfully
     */
    public boolean connectWithRetry(int maxRetries) {
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                // Create new internal client for each attempt
                // Java-WebSocket doesn't allow reusing a client after connection attempt
                createInternalClient();

                logger.info("Connection attempt {}/{}", attempt, maxRetries);
                if (connectAndWait(5000)) {
                    return true;
                }

                if (attempt < maxRetries) {
                    long delay = (long) Math.pow(2, attempt - 1) * 1000; // Exponential backoff
                    logger.warn("Connection failed, retrying in {} ms", delay);
                    TimeUnit.MILLISECONDS.sleep(delay);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                logger.error("Connection retry interrupted", e);
                return false;
            }
        }
        return false;
    }

    /**
     * Connect to server and wait for connection to be established.
     *
     * @param timeoutMs maximum time to wait for connection in milliseconds
     * @return true if connection established successfully
     */
    public boolean connectAndWait(long timeoutMs) {
        try {
            internalClient.connect();
            return connectLatch.await(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (Exception e) {
            logger.error("Failed to connect to WebSocket server", e);
            return false;
        }
    }

    /**
     * Closes the WebSocket connection and releases resources.
     */
    @Override
    public void close() {
        disconnect();
    }

    /**
     * Disconnect from the WebSocket server.
     */
    public void disconnect() {
        if (internalClient != null) {
            internalClient.close();
        }
        connected = false;
    }

    /**
     * Check if the WebSocket connection is currently active.
     *
     * @return true if connected, false otherwise
     */
    public boolean isConnected() {
        return connected && internalClient != null && !internalClient.isClosed();
    }

    // Message sending

    /**
     * Send a text message to the server.
     *
     * @param message text message to send
     */
    public void sendTextMessage(String message) {
        if (!isConnected()) {
            logger.warn("Cannot send message: not connected");
            return;
        }
        internalClient.send(message);
        logger.debug("Sent text message: {}", message);
    }

    /**
     * Send binary data to the server.
     *
     * @param data binary data to send
     */
    public void sendBinaryMessage(byte[] data) {
        if (!isConnected()) {
            logger.warn("Cannot send binary data: not connected");
            return;
        }
        internalClient.send(data);
        logger.debug("Sent binary data: {} bytes", data.length);
    }


    /**
     * Wait for a binary message with timeout.
     *
     * @param timeoutMs maximum time to wait in milliseconds
     * @return received binary data, or null if timeout
     */
    public byte[] waitForBinaryMessage(long timeoutMs) {
        try {
            return binaryMessageQueue.poll(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warn("Binary message wait interrupted");
            return null;
        }
    }

    /**
     * Wait for a text message with timeout.
     *
     * @param timeoutMs maximum time to wait in milliseconds
     * @return received text message, or null if timeout
     */
    public String waitForTextMessage(long timeoutMs) {
        try {
            return textMessageQueue.poll(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warn("Text message wait interrupted");
            return null;
        }
    }

    /**
     * Clear all pending messages in the queues.
     */
    public void clearMessages() {
        binaryMessageQueue.clear();
        textMessageQueue.clear();
    }
}
