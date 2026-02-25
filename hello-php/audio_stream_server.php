#!/usr/bin/env php
<?php

declare(strict_types=1);

require_once __DIR__ . '/vendor/autoload.php';

use AudioStream\Server\Server;

$port = 8080;
$cacheDir = 'cache';

for ($i = 1; $i < $argc; $i++) {
    if ($argv[$i] === '--port' && $i + 1 < $argc) {
        $port = (int) $argv[++$i];
    } elseif ($argv[$i] === '--cache-dir' && $i + 1 < $argc) {
        $cacheDir = $argv[++$i];
    }
}

$server = new Server($port, $cacheDir);
$server->start();
