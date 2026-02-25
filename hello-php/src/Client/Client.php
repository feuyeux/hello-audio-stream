<?php

declare(strict_types=1);

namespace AudioStream\Client;

use WebSocket\Client as WsClient;

final class Client
{
    private const CHUNK_SIZE = 8192;
    private const READ_SIZE = 65536;

    public function __construct(
        private readonly string $serverUri,
        private readonly string $inputFile,
        private readonly string $outputDir,
    ) {}

    public function run(): void
    {
        if (!is_dir($this->outputDir)) {
            mkdir($this->outputDir, 0755, true);
        }

        $ws = new WsClient($this->serverUri, ['timeout' => 30]);
        try {
            // Wait for CONNECTED
            $connMsg = $this->receiveJson($ws);
            echo "Connected: {$connMsg['streamId']}\n";

            // Upload
            $streamId = $this->upload($ws);

            // Get status
            $ws->text(json_encode(['command' => 'GET_STATUS', 'streamId' => $streamId]));
            $statusMsg = $this->receiveJson($ws);
            $fileSize = $statusMsg['size'];
            echo "Status: {$statusMsg['status']}, size: {$fileSize}\n";

            // Download
            $outputPath = $this->outputDir . DIRECTORY_SEPARATOR . basename($this->inputFile);
            $this->download($ws, $streamId, $outputPath, $fileSize);

            // Verify
            $this->verify($outputPath);

            // Close stream
            $ws->text(json_encode(['command' => 'CLOSE', 'streamId' => $streamId]));
            $closeMsg = $this->receiveJson($ws);
            echo "Stream closed: {$closeMsg['command']}\n";
        } finally {
            $ws->close();
        }
    }

    private function upload(WsClient $ws): string
    {
        $fileSize = filesize($this->inputFile);
        $streamId = 'stream-' . bin2hex(random_bytes(4));

        echo "========================================\n";
        echo "Phase 1: Upload\n";
        echo "========================================\n";
        echo "Stream: {$streamId}, size: {$fileSize}\n";

        // CREATE
        $ws->text(json_encode(['command' => 'CREATE', 'streamId' => $streamId]));
        $created = $this->receiveJson($ws);
        if ($created['command'] !== 'CREATED') {
            throw new \RuntimeException("Expected CREATED, got: {$created['command']}");
        }

        // Send binary data
        $handle = fopen($this->inputFile, 'rb');
        $sent = 0;
        $lastReport = 0;
        while (!feof($handle)) {
            $chunk = fread($handle, self::CHUNK_SIZE);
            if ($chunk === false || strlen($chunk) === 0) {
                break;
            }
            $ws->send($chunk, 'binary');
            $sent += strlen($chunk);

            $pct = (int) ($sent * 100 / $fileSize);
            if ($pct >= $lastReport + 25) {
                echo "  Upload: {$pct}% ({$sent} / {$fileSize})\n";
                $lastReport = (int) ($pct / 25) * 25;
            }
        }
        fclose($handle);
        echo "  Upload: 100% ({$fileSize} / {$fileSize})\n";

        // COMPLETE
        $ws->text(json_encode(['command' => 'COMPLETE']));
        $completed = $this->receiveJson($ws);
        if ($completed['command'] !== 'COMPLETED') {
            throw new \RuntimeException("Expected COMPLETED, got: {$completed['command']}");
        }
        echo "Upload completed\n";

        return $streamId;
    }

    private function download(WsClient $ws, string $streamId, string $outputPath, int $fileSize): void
    {
        echo "========================================\n";
        echo "Phase 2: Download\n";
        echo "========================================\n";
        echo "Output: {$outputPath}\n";

        if (file_exists($outputPath)) {
            unlink($outputPath);
        }

        $handle = fopen($outputPath, 'wb');
        $offset = 0;
        $lastReport = 0;

        while ($offset < $fileSize) {
            $length = min(self::READ_SIZE, $fileSize - $offset);
            $ws->text(json_encode([
                'command' => 'READ',
                'streamId' => $streamId,
                'offset' => $offset,
                'length' => $length,
            ]));

            $data = $ws->receive();
            if ($data === null || strlen($data) === 0) {
                throw new \RuntimeException("No data at offset {$offset}");
            }

            $actual = min(strlen($data), $fileSize - $offset);
            fwrite($handle, substr($data, 0, $actual));
            $offset += $actual;

            $pct = (int) ($offset * 100 / $fileSize);
            if ($pct >= $lastReport + 25) {
                echo "  Download: {$pct}% ({$offset} / {$fileSize})\n";
                $lastReport = (int) ($pct / 25) * 25;
            }
        }
        fclose($handle);
        echo "  Download: 100% ({$fileSize} / {$fileSize})\n";
        echo "Download completed\n";
    }

    private function verify(string $outputPath): void
    {
        echo "========================================\n";
        echo "Phase 3: Verification\n";
        echo "========================================\n";

        $origSize = filesize($this->inputFile);
        $dlSize = filesize($outputPath);
        $origMd5 = md5_file($this->inputFile);
        $dlMd5 = md5_file($outputPath);

        echo "Original:   size={$origSize}, md5={$origMd5}\n";
        echo "Downloaded: size={$dlSize}, md5={$dlMd5}\n";

        if ($origSize === $dlSize && $origMd5 === $dlMd5) {
            echo "Verification PASSED\n";
        } else {
            echo "Verification FAILED\n";
        }
    }

    private function receiveJson(WsClient $ws): array
    {
        $msg = $ws->receive();
        $data = json_decode($msg, true);
        if (!is_array($data)) {
            throw new \RuntimeException("Invalid JSON response: {$msg}");
        }
        return $data;
    }
}
