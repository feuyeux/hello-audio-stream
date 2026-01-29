<?php

/**
 * WebSocket message handler for processing client messages.
 * Handles START, STOP, GET, and binary messages.
 * Matches Java WebSocketMessageHandler functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Handler;

use AudioStreamClient\Logger;
use AudioStreamServer\Memory\StreamManager;
use AudioStreamServer\Memory\StreamStatus;
use Ratchet\ConnectionInterface;

/**
 * Message handler for WebSocket audio streaming protocol.
 */
class WebSocketMessageHandler
{
    private StreamManager $streamManager;
    private \WeakMap $activeStreams; // Maps client to active streamId

    /**
     * Create a new WebSocketMessageHandler.
     *
     * @param StreamManager $streamManager Stream manager instance
     */
    public function __construct(StreamManager $streamManager)
    {
        $this->streamManager = $streamManager;
        $this->activeStreams = new \WeakMap();
    }

    /**
     * Handle incoming message from client.
     *
     * @param ConnectionInterface $conn Client connection
     * @param string $msg Message data
     */
    public function handleMessage(ConnectionInterface $conn, string $msg): void
    {
        try {
            // Check if message is binary (contains non-UTF-8 characters)
            if (!mb_check_encoding($msg, 'UTF-8')) {
                $this->handleBinaryMessage($conn, $msg);
            } else {
                // Try to parse as JSON
                $data = json_decode($msg, true);
                if (json_last_error() === JSON_ERROR_NONE && is_array($data)) {
                    $wsMsg = WebSocketMessage::fromArray($data);
                    $this->handleTextMessage($conn, $wsMsg);
                } else {
                    // Not valid JSON, treat as binary
                    $this->handleBinaryMessage($conn, $msg);
                }
            }

        } catch (\Exception $e) {
            Logger::error("Error handling message: " . $e->getMessage());
            $this->sendError($conn, $e->getMessage());
        }
    }

    /**
     * Register a stream for a client connection.
     *
     * @param ConnectionInterface $conn Client connection
     * @param string $streamId Stream ID
     */
    public function registerStream(ConnectionInterface $conn, string $streamId): void
    {
        $this->activeStreams[$conn] = $streamId;
    }

    /**
     * Unregister a stream for a client connection.
     *
     * @param ConnectionInterface $conn Client connection
     */
    public function unregisterStream(ConnectionInterface $conn): void
    {
        if (isset($this->activeStreams[$conn])) {
            unset($this->activeStreams[$conn]);
        }
    }

    /**
     * Handle a text (JSON) control message.
     *
     * @param ConnectionInterface $conn Client connection
     * @param WebSocketMessage $msg Parsed message
     */
    private function handleTextMessage(ConnectionInterface $conn, WebSocketMessage $msg): void
    {
        $msgType = strtoupper($msg->type);

        switch ($msgType) {
            case 'START':
                $this->handleStart($conn, $msg);
                break;
            case 'STOP':
                $this->handleStop($conn, $msg);
                break;
            case 'GET':
                $this->handleGet($conn, $msg);
                break;
            default:
                Logger::warning("Unknown message type: {$msgType}");
                $this->sendError($conn, "Unknown message type: {$msgType}");
                break;
        }
    }

    /**
     * Handle binary audio data.
     *
     * @param ConnectionInterface $conn Client connection
     * @param string $data Binary audio data
     */
    private function handleBinaryMessage(ConnectionInterface $conn, string $data): void
    {
        // Get active stream ID for this client
        $streamId = $this->activeStreams[$conn] ?? null;

        if ($streamId === null) {
            Logger::warning('Received binary data but no active stream for client');
            return;
        }

        Logger::debug("Received " . strlen($data) . " bytes of binary data for stream {$streamId}");

        // Write to stream
        $this->streamManager->writeChunk($streamId, $data);
    }

    /**
     * Handle START message (create new stream).
     *
     * @param ConnectionInterface $conn Client connection
     * @param WebSocketMessage $msg Parsed message
     */
    private function handleStart(ConnectionInterface $conn, WebSocketMessage $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->sendError($conn, 'Missing streamId');
            return;
        }

        // Create stream
        if ($this->streamManager->createStream($streamId)) {
            // Register this client with the stream
            $this->registerStream($conn, $streamId);

            $response = WebSocketMessage::started($streamId);
            $this->sendMessage($conn, $response);
            Logger::info("Stream started: {$streamId}");
        } else {
            $this->sendError($conn, "Failed to create stream: {$streamId}");
        }
    }

    /**
     * Handle STOP message (finalize stream).
     *
     * @param ConnectionInterface $conn Client connection
     * @param WebSocketMessage $msg Parsed message
     */
    private function handleStop(ConnectionInterface $conn, WebSocketMessage $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->sendError($conn, 'Missing streamId');
            return;
        }

        // Finalize stream
        if ($this->streamManager->finalizeStream($streamId)) {
            $response = WebSocketMessage::stopped($streamId);
            $this->sendMessage($conn, $response);
            Logger::info("Stream finalized: {$streamId}");

            // Unregister stream from client
            $this->unregisterStream($conn);
        } else {
            $this->sendError($conn, "Failed to finalize stream: {$streamId}");
        }
    }

    /**
     * Handle GET message (read stream data).
     *
     * @param ConnectionInterface $conn Client connection
     * @param WebSocketMessage $msg Parsed message
     */
    private function handleGet(ConnectionInterface $conn, WebSocketMessage $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->sendError($conn, 'Missing streamId');
            return;
        }

        $offset = $msg->offset ?? 0;
        $length = $msg->length ?? 65536;

        // Read data from stream
        $chunkData = $this->streamManager->readChunk($streamId, $offset, $length);

        if (strlen($chunkData) > 0) {
            // Send binary data
            $conn->send($chunkData);
            Logger::debug("Sent " . strlen($chunkData) . " bytes for stream {$streamId} at offset {$offset}");
        } else {
            $this->sendError($conn, "Failed to read from stream: {$streamId}");
        }
    }

    /**
     * Send a WebSocketMessage to the client.
     *
     * @param ConnectionInterface $conn Client connection
     * @param WebSocketMessage $msg Message to send
     */
    private function sendMessage(ConnectionInterface $conn, WebSocketMessage $msg): void
    {
        $json = $msg->toJson();
        $conn->send($json);
    }

    /**
     * Send a JSON message to the client.
     *
     * @param ConnectionInterface $conn Client connection
     * @param array $data Data to send
     */
    private function sendJSON(ConnectionInterface $conn, array $data): void
    {
        $json = json_encode($data);
        if ($json !== false) {
            $conn->send($json);
        }
    }

    /**
     * Send an error message to the client.
     *
     * @param ConnectionInterface $conn Client connection
     * @param string $message Error message
     */
    private function sendError(ConnectionInterface $conn, string $message): void
    {
        $response = WebSocketMessage::error($message);
        $this->sendMessage($conn, $response);
        Logger::error("Sent error to client: {$message}");
    }
}

