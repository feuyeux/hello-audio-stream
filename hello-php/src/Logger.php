<?php

namespace AudioStreamClient;

class Logger
{
    private static bool $verboseEnabled = false;

    public static function setVerbose(bool $enabled): void
    {
        self::$verboseEnabled = $enabled;
    }

    public static function debug(string $message): void
    {
        if (self::$verboseEnabled) {
            self::log('debug', $message);
        }
    }

    public static function info(string $message): void
    {
        self::log('info', $message);
    }

    public static function warn(string $message): void
    {
        self::log('warn', $message);
    }

    public static function warning(string $message): void
    {
        self::warn($message);
    }

    public static function error(string $message): void
    {
        self::log('error', $message);
    }

    private static function log(string $level, string $message): void
    {
        $timestamp = date('Y-m-d H:i:s.') . substr(microtime(), 2, 3);
        echo "[$timestamp] [$level] $message\n";
    }
}
