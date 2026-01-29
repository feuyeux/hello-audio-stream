<?php

/**
 * Path validating WebSocket server wrapper.
 * Validates the request path before delegating to the actual server.
 */

declare(strict_types=1);

namespace AudioStreamServer\Network;

use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;
use Ratchet\Http\HttpServerInterface;
use Psr\Http\Message\RequestInterface;

/**
 * Validates WebSocket connection path.
 */
class PathValidatingServer implements HttpServerInterface
{
    private MessageComponentInterface $component;
    private string $expectedPath;

    public function __construct(MessageComponentInterface $component, string $expectedPath)
    {
        $this->component = $component;
        $this->expectedPath = $expectedPath;
    }

    public function onOpen(ConnectionInterface $conn, RequestInterface $request = null)
    {
        if ($request === null) {
            $conn->close();
            return;
        }

        $path = $request->getUri()->getPath();
        
        if ($path !== $this->expectedPath) {
            $conn->send("HTTP/1.1 404 Not Found\r\n\r\n");
            $conn->close();
            return;
        }

        $this->component->onOpen($conn);
    }

    public function onMessage(ConnectionInterface $from, $msg)
    {
        $this->component->onMessage($from, $msg);
    }

    public function onClose(ConnectionInterface $conn)
    {
        $this->component->onClose($conn);
    }

    public function onError(ConnectionInterface $conn, \Exception $e)
    {
        $this->component->onError($conn, $e);
    }
}
