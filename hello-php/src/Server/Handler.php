<?php

declare(strict_types=1);

namespace AudioStream\Server;

use Ratchet\ConnectionInterface;

final class Handler
{
    private ?string $streamId = null;

    public function __construct(
        private readonly string $connId,
        private readonly StreamManager $manager,
        private readonly ConnectionInterface $conn,
    ) {
        $this->send(Message::connected($this->connId));
        echo "[{$this->connId}] connected\n";
    }

    public function onMessage(string $msg): void
    {
        try {
            $data = json_decode($msg, true);
            if (is_array($data) && isset($data['command'])) {
                $this->handleText($msg);
            } else {
                $this->handleBinary($msg);
            }
        } catch (\Exception $e) {
            $this->send(Message::error($e->getMessage()));
        }
    }

    public function onClose(): void
    {
        if ($this->streamId !== null) {
            $this->manager->markError($this->streamId);
        }
        echo "[{$this->connId}] disconnected\n";
    }

    private function handleText(string $json): void
    {
        [$info, $msg] = Message::parseCommand($json);

        match ($info->type) {
            CommandType::STREAM => $this->handleStream($msg),
            CommandType::DATA => $this->handleData($msg),
            CommandType::QUERY => $this->handleQuery($msg),
        };
    }

    private function handleBinary(string $data): void
    {
        if ($this->streamId === null) {
            $this->send(Message::error('No active stream'));
            return;
        }
        if (!$this->manager->write($this->streamId, $data)) {
            $this->send(Message::error('Write failed'));
        }
    }

    private function handleStream(Message $msg): void
    {
        match ($msg->command) {
            'CREATE' => $this->handleCreate($msg),
            'COMPLETE' => $this->handleComplete(),
            'CLOSE' => $this->handleClose($msg),
            default => $this->send(Message::error("Unknown stream command: {$msg->command}")),
        };
    }

    private function handleData(Message $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->send(Message::error('Missing streamId'));
            return;
        }

        $offset = $msg->offset ?? 0;
        $length = $msg->length ?? 65536;

        $data = $this->manager->read($streamId, $offset, $length);
        if (strlen($data) > 0) {
            $this->conn->send($data);
        } else {
            $this->send(Message::error("Read failed: {$streamId}"));
        }
    }

    private function handleQuery(Message $msg): void
    {
        match ($msg->command) {
            'GET_STATUS' => $this->handleGetStatus($msg),
            'LIST_STREAMS' => $this->handleListStreams(),
            default => $this->send(Message::error("Unknown query command: {$msg->command}")),
        };
    }

    private function handleCreate(Message $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->send(Message::error('Missing streamId'));
            return;
        }
        if ($this->manager->create($streamId)) {
            $this->streamId = $streamId;
            $this->send(Message::created($streamId));
            echo "[{$this->connId}] created stream: {$streamId}\n";
        } else {
            $this->send(Message::error("Failed to create stream: {$streamId}"));
        }
    }

    private function handleComplete(): void
    {
        if ($this->streamId === null) {
            $this->send(Message::error('No active stream'));
            return;
        }
        if ($this->manager->complete($this->streamId)) {
            $this->send(Message::completed($this->streamId));
            echo "[{$this->connId}] completed stream: {$this->streamId}\n";
            $this->streamId = null;
        } else {
            $this->send(Message::error("Failed to complete stream: {$this->streamId}"));
        }
    }

    private function handleClose(Message $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->send(Message::error('Missing streamId'));
            return;
        }
        if ($this->manager->delete($streamId)) {
            $this->send(Message::closed($streamId));
            echo "[{$this->connId}] closed stream: {$streamId}\n";
        } else {
            $this->send(Message::error("Failed to close stream: {$streamId}"));
        }
    }

    private function handleGetStatus(Message $msg): void
    {
        $streamId = $msg->streamId ?? '';
        if ($streamId === '') {
            $this->send(Message::error('Missing streamId'));
            return;
        }
        $info = $this->manager->statusOf($streamId);
        if ($info !== null) {
            $this->send(Message::status($streamId, $info['status'], $info['size']));
        } else {
            $this->send(Message::error("Stream not found: {$streamId}"));
        }
    }

    private function handleListStreams(): void
    {
        $ids = $this->manager->list();
        $this->send(Message::streamList(implode(',', $ids)));
    }

    private function send(Message $msg): void
    {
        $this->conn->send($msg->toJson());
    }
}
