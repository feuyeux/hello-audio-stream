<?php

/**
 * WebSocket message class for JSON serialization/deserialization.
 * Used for all control messages between client and server.
 */

declare(strict_types=1);

namespace AudioStreamServer\Handler;

/**
 * WebSocket control message POJO.
 */
class WebSocketMessage
{
    public string $type;
    public ?string $streamId;
    public ?int $offset;
    public ?int $length;
    public ?string $message;

    public function __construct(
        string $type,
        ?string $streamId = null,
        ?int $offset = null,
        ?int $length = null,
        ?string $message = null
    ) {
        $this->type = $type;
        $this->streamId = $streamId;
        $this->offset = $offset;
        $this->length = $length;
        $this->message = $message;
    }

    /**
     * Convert to JSON string, excluding null values.
     */
    public function toJson(): string
    {
        $data = ['type' => $this->type];
        if ($this->streamId !== null) {
            $data['streamId'] = $this->streamId;
        }
        if ($this->offset !== null) {
            $data['offset'] = $this->offset;
        }
        if ($this->length !== null) {
            $data['length'] = $this->length;
        }
        if ($this->message !== null) {
            $data['message'] = $this->message;
        }
        return json_encode($data) ?: '{}';
    }

    /**
     * Convert to array, excluding null values.
     */
    public function toArray(): array
    {
        $data = ['type' => $this->type];
        if ($this->streamId !== null) {
            $data['streamId'] = $this->streamId;
        }
        if ($this->offset !== null) {
            $data['offset'] = $this->offset;
        }
        if ($this->length !== null) {
            $data['length'] = $this->length;
        }
        if ($this->message !== null) {
            $data['message'] = $this->message;
        }
        return $data;
    }

    /**
     * Parse from JSON string.
     */
    public static function fromJson(string $json): self
    {
        $data = json_decode($json, true);
        if (!is_array($data)) {
            throw new \InvalidArgumentException('Invalid JSON');
        }
        return self::fromArray($data);
    }

    /**
     * Parse from array.
     */
    public static function fromArray(array $data): self
    {
        return new self(
            $data['type'] ?? '',
            $data['streamId'] ?? null,
            isset($data['offset']) ? (int)$data['offset'] : null,
            isset($data['length']) ? (int)$data['length'] : null,
            $data['message'] ?? null
        );
    }

    /**
     * Create a STARTED response message.
     */
    public static function started(string $streamId, string $message = 'Stream started successfully'): self
    {
        return new self('STARTED', $streamId, null, null, $message);
    }

    /**
     * Create a STOPPED response message.
     */
    public static function stopped(string $streamId, string $message = 'Stream finalized successfully'): self
    {
        return new self('STOPPED', $streamId, null, null, $message);
    }

    /**
     * Create an ERROR response message.
     */
    public static function error(string $message): self
    {
        return new self('ERROR', null, null, null, $message);
    }
}
