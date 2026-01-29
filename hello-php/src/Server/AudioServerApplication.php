<?php

/**
 * Main entry point for PHP audio stream server.
 * Initializes and starts the WebSocket server.
 * Matches Java AudioServerApplication functionality.
 */

declare(strict_types=1);

namespace AudioStreamServer;

use AudioStreamServer\Network\AudioWebSocketServer;
use AudioStreamServer\Memory\StreamManager;
use AudioStreamServer\Memory\MemoryPoolManager;

/**
 * Audio server application entry point.
 */
class AudioServerApplication
{
    private int $port;
    private string $path;
    private AudioWebSocketServer $server;
    private StreamManager $streamManager;
    private MemoryPoolManager $memoryPool;

    /**
     * Create a new AudioServerApplication.
     *
     * @param int $port Port number to listen on (default 8080)
     * @param string $path WebSocket endpoint path (default '/audio')
     * @param string $cacheDir Cache directory (default 'cache')
     */
    public function __construct(int $port = 8080, string $path = '/audio', string $cacheDir = 'cache')
    {
        $this->port = $port;
        $this->path = $path;
        
        // Get singleton instances
        $this->streamManager = StreamManager::getInstance($cacheDir);
        $this->memoryPool = MemoryPoolManager::getInstance(65536, 100);

        // Create WebSocket server
        $this->server = new AudioWebSocketServer($port, $path, $this->streamManager, $this->memoryPool);
    }

    /**
     * Start the server.
     */
    public function start(): void
    {
        // Use Ratchet with React to run the server
        $loop = \React\EventLoop\Loop::get();
        
        // Create WebSocket server (without path validation for now)
        $webSock = new \React\Socket\SocketServer("0.0.0.0:{$this->port}", [], $loop);
        $webServer = new \Ratchet\Server\IoServer(
            new \Ratchet\Http\HttpServer(
                new \Ratchet\WebSocket\WsServer(
                    $this->server
                )
            ),
            $webSock,
            $loop
        );

        echo "AudioServerApplication started on ws://0.0.0.0:{$this->port}\n";
        echo "Note: Path validation disabled, accepting all connections\n";

        $loop->run();
    }

    /**
     * Get the server instance.
     *
     * @return AudioWebSocketServer Server instance
     */
    public function getServer(): AudioWebSocketServer
    {
        return $this->server;
    }
}
