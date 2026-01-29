<?php

/**
 * Main entry point for PHP audio stream server.
 */

declare(strict_types=1);

require_once __DIR__ . '/../../vendor/autoload.php';

use AudioStreamServer\AudioServerApplication;

// Parse command-line arguments
$port = 8080;
$path = '/audio';
$cacheDir = 'cache';

for ($i = 1; $i < $argc; $i++) {
    if ($argv[$i] === '--port' && $i + 1 < $argc) {
        $port = (int)$argv[$i + 1];
        $i++;
    } elseif ($argv[$i] === '--path' && $i + 1 < $argc) {
        $path = $argv[$i + 1];
        $i++;
    } elseif ($argv[$i] === '--cache-dir' && $i + 1 < $argc) {
        $cacheDir = $argv[$i + 1];
        $i++;
    }
}

echo "Starting Audio Server on port $port with path $path\n";

// Create and start the server
$app = new AudioServerApplication($port, $path, $cacheDir);
$app->start();
