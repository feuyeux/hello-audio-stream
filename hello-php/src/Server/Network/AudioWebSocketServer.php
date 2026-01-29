<?php

/**
 * WebSocket server for audio streaming.
 * Handles client connections and delegates message processing to handler.
 * Matches Python AudioWebSocketServer and Java AudioWebSocketServer functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer\Network;

use AudioStreamClient\Logger;
use AudioStreamServer\Handler\WebSocketMessageHandler;
use AudioStreamServer\Memory\StreamManager;
use AudioStreamServer\Memory\MemoryPoolManager;
use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;

/**
 * WebSocket server for handling audio stream uploads and downloads.
 */
class AudioWebSocketServer implements MessageComponentInterface
{
    private int $port;
    private string $path;
    private \SplObjectStorage $clients;
    private WebSocketMessageHandler $messageHandler;
    private StreamManager $streamManager;
    private MemoryPoolManager $memoryPool;

    /**
     * Initialize WebSocket server.
     *
     * @param int $port Port number to listen on
     * @param string $path WebSocket endpoint path
     * @param StreamManager $streamManager Stream manager instance
     * @param MemoryPoolManager $memoryPool Memory pool instance
     */
    public function __construct(
        int $port = 8080,
        string $path = '/audio',
        ?StreamManager $streamManager = null,
        ?MemoryPoolManager $memoryPool = null
    ) {
        $this->port = $port;
        $this->path = $path;
        $this->clients = new \SplObjectStorage();

        // Use singleton instances if not provided
        $this->streamManager = $streamManager ?? StreamManager::getInstance('cache');
        $this->memoryPool = $memoryPool ?? MemoryPoolManager::getInstance(65536, 100);

        // Create message handler
        $this->messageHandler = new WebSocketMessageHandler($this->streamManager);

        Logger::info("AudioWebSocketServer initialized on port {$port}{$path}");
    }

    /**
     * Handle new client connection.
     *
     * @param ConnectionInterface $conn Client connection
     */
    public function onOpen(ConnectionInterface $conn): void
    {
        $this->clients->attach($conn);
        $clientAddr = $conn->remoteAddress;
        Logger::info("Client connected: {$clientAddr}");
    }

    /**
     * Handle client disconnection.
     *
     * @param ConnectionInterface $conn Client connection
     */
    public function onClose(ConnectionInterface $conn): void
    {
        $this->clients->detach($conn);
        $this->messageHandler->unregisterStream($conn);
        $clientAddr = $conn->remoteAddress;
        Logger::info("Client disconnected: {$clientAddr}");
    }

    /**
     * Handle incoming message from client.
     *
     * @param ConnectionInterface $from Sender connection
     * @param mixed $msg Message data
     */
    public function onMessage(ConnectionInterface $from, $msg): void
    {
        $this->messageHandler->handleMessage($from, $msg);
    }

    /**
     * Handle connection error.
     *
     * @param ConnectionInterface $conn Client connection
     * @param \Exception $e Exception
     */
    public function onError(ConnectionInterface $conn, \Exception $e): void
    {
        Logger::error("Connection error: " . $e->getMessage());
        $conn->close();
    }

    /**
     * Get the port number.
     *
     * @return int Port number
     */
    public function getPort(): int
    {
        return $this->port;
    }

    /**
     * Get the endpoint path.
     *
     * @return string Endpoint path
     */
    public function getPath(): string
    {
        return $this->path;
    }
}

