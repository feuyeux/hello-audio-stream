<?php

namespace AudioStreamClient\Core;

use AudioStreamClient\Logger;
use WebSocket\Client;

class WebSocketClient
{
    private string $uri;
    private ?Client $client = null;

    public function __construct(string $uri)
    {
        $this->uri = $uri;
    }

    public function connect(): void
    {
        Logger::info('Connecting to ' . $this->uri);
        $this->client = new Client($this->uri, [
            'fragment_size' => 16384, // 16KB - larger than our 8KB chunks to avoid fragmentation
            'timeout' => 30,
        ]);
        Logger::info('Connected to server');
    }

    public function sendText(array $message): void
    {
        $json = json_encode($message);
        Logger::debug('Sending: ' . $json);
        $this->client->text($json);
    }

    public function sendBinary(string $data): void
    {
        Logger::debug('Sending binary data: ' . strlen($data) . ' bytes');
        // Use send() with 'binary' opcode
        $this->client->send($data, 'binary');
    }

    public function receiveText(): string
    {
        $msg = $this->client->receive();
        Logger::debug('Received: ' . substr($msg, 0, 100));
        return $msg;
    }

    public function receiveBinary(): string
    {
        $msg = $this->client->receive();
        
        // Check if this is actually a text message (JSON error)
        if (is_string($msg) && strlen($msg) > 0 && ($msg[0] === '{' || $msg[0] === '[')) {
            Logger::debug('Received text instead of binary: ' . $msg);
            throw new \Exception('Expected binary data but received text: ' . $msg);
        }
        
        Logger::debug('Received binary data: ' . strlen($msg) . ' bytes');
        return $msg;
    }

    public function close(): void
    {
        if ($this->client !== null) {
            $this->client->close();
            Logger::info('Disconnected from server');
        }
    }
}
