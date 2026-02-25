<?php

declare(strict_types=1);

namespace AudioStream\Server;

use Ratchet\ConnectionInterface;
use Ratchet\MessageComponentInterface;
use React\EventLoop\Loop;

final class Server implements MessageComponentInterface
{
    private StreamManager $manager;
    private \SplObjectStorage $handlers;
    private int $connSeq = 0;

    public function __construct(
        private readonly int $port = 8080,
        string $cacheDir = 'cache',
    ) {
        $this->manager = new StreamManager($cacheDir);
        $this->handlers = new \SplObjectStorage();
    }

    public function start(): void
    {
        $loop = Loop::get();

        $loop->addPeriodicTimer(30, function () {
            $removed = $this->manager->cleanup();
            if ($removed > 0) {
                $stats = $this->manager->stats();
                echo "Cleanup: removed {$removed} streams, total={$stats['total']}\n";
            }
        });

        $socket = new \React\Socket\SocketServer("0.0.0.0:{$this->port}", [], $loop);
        new \Ratchet\Server\IoServer(
            new \Ratchet\Http\HttpServer(
                new \Ratchet\WebSocket\WsServer($this)
            ),
            $socket,
            $loop,
        );

        echo "Server started on ws://0.0.0.0:{$this->port}\n";
        $loop->run();
    }

    public function onOpen(ConnectionInterface $conn): void
    {
        $connId = 'c-' . (++$this->connSeq);
        $handler = new Handler($connId, $this->manager, $conn);
        $this->handlers->attach($conn, $handler);
    }

    public function onMessage(ConnectionInterface $from, $msg): void
    {
        /** @var Handler|null $handler */
        $handler = $this->handlers->contains($from) ? $this->handlers[$from] : null;
        if ($handler !== null) {
            $handler->onMessage((string) $msg);
        }
    }

    public function onClose(ConnectionInterface $conn): void
    {
        if ($this->handlers->contains($conn)) {
            /** @var Handler $handler */
            $handler = $this->handlers[$conn];
            $handler->onClose();
            $this->handlers->detach($conn);
        }
    }

    public function onError(ConnectionInterface $conn, \Exception $e): void
    {
        echo "Error: " . $e->getMessage() . "\n";
        $conn->close();
    }
}
