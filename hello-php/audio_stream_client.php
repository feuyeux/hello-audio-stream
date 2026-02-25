#!/usr/bin/env php
<?php

declare(strict_types=1);

require_once __DIR__ . '/vendor/autoload.php';

use AudioStream\Client\Client;

$serverUri = 'ws://localhost:8080';
$inputFile = '../audio/input/hello.opus';
$outputDir = 'audio/output';

for ($i = 1; $i < $argc; $i++) {
    if ($argv[$i] === '--server' && $i + 1 < $argc) {
        $serverUri = $argv[++$i];
    } elseif ($argv[$i] === '--input' && $i + 1 < $argc) {
        $inputFile = $argv[++$i];
    } elseif ($argv[$i] === '--output' && $i + 1 < $argc) {
        $outputDir = $argv[++$i];
    }
}

$client = new Client($serverUri, $inputFile, $outputDir);
$client->run();
