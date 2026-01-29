#!/usr/bin/env php
<?php

require_once __DIR__ . '/vendor/autoload.php';

use AudioStreamClient\CliParser;
use AudioStreamClient\Logger;
use AudioStreamClient\AudioClientApplication;

try {
    $config = CliParser::parse($argv);
    if ($config === null) {
        exit(1);
    }

    $app = new AudioClientApplication($config);
    $exitCode = $app->run();
    exit($exitCode);

} catch (Exception $e) {
    Logger::error('Fatal error: ' . $e->getMessage());
    exit(1);
}
