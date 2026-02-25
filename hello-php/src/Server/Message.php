<?php

declare(strict_types=1);

namespace AudioStream\Server;

final class Message
{
    public function __construct(
        public readonly string $command,
        public readonly ?string $streamId = null,
        public readonly ?int $offset = null,
        public readonly ?int $length = null,
        public readonly ?string $message = null,
        public readonly ?string $status = null,
        public readonly ?int $size = null,
        public readonly ?string $streams = null,
    ) {}

    public function toJson(): string
    {
        $data = ['command' => $this->command];
        if ($this->streamId !== null) $data['streamId'] = $this->streamId;
        if ($this->offset !== null) $data['offset'] = $this->offset;
        if ($this->length !== null) $data['length'] = $this->length;
        if ($this->message !== null) $data['message'] = $this->message;
        if ($this->status !== null) $data['status'] = $this->status;
        if ($this->size !== null) $data['size'] = $this->size;
        if ($this->streams !== null) $data['streams'] = $this->streams;
        return json_encode($data) ?: '{}';
    }

    public static function parse(string $json): self
    {
        $data = json_decode($json, true);
        if (!is_array($data) || !isset($data['command'])) {
            throw new \InvalidArgumentException('Invalid message: missing command field');
        }
        return new self(
            command: $data['command'],
            streamId: $data['streamId'] ?? null,
            offset: isset($data['offset']) ? (int) $data['offset'] : null,
            length: isset($data['length']) ? (int) $data['length'] : null,
            message: $data['message'] ?? null,
            status: $data['status'] ?? null,
            size: isset($data['size']) ? (int) $data['size'] : null,
            streams: $data['streams'] ?? null,
        );
    }

    /**
     * @return array{CommandInfo, Message}
     */
    public static function parseCommand(string $json): array
    {
        $msg = self::parse($json);
        $info = Protocol::lookup($msg->command);
        if ($info === null) {
            throw new \InvalidArgumentException("Unknown command: {$msg->command}");
        }
        return [$info, $msg];
    }

    // --- Factory methods ---

    public static function connected(string $connId): self
    {
        return new self(command: 'CONNECTED', streamId: $connId);
    }

    public static function created(string $streamId): self
    {
        return new self(command: 'CREATED', streamId: $streamId);
    }

    public static function completed(string $streamId): self
    {
        return new self(command: 'COMPLETED', streamId: $streamId);
    }

    public static function closed(string $streamId): self
    {
        return new self(command: 'CLOSED', streamId: $streamId);
    }

    public static function status(string $streamId, string $status, int $size): self
    {
        return new self(command: 'STATUS', streamId: $streamId, status: $status, size: $size);
    }

    public static function streamList(string $streams): self
    {
        return new self(command: 'STREAM_LIST', streams: $streams);
    }

    public static function error(string $message): self
    {
        return new self(command: 'ERROR', message: $message);
    }
}
