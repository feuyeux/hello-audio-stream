<?php

namespace AudioStreamClient;

class CliParser
{
    public static function parse(array $argv): ?array
    {
        $options = [
            'inputPath' => null,
            'outputPath' => null,
            'serverUri' => 'ws://localhost:8080/audio',
            'verbose' => false,
        ];

        for ($i = 1; $i < count($argv); $i++) {
            switch ($argv[$i]) {
                case '--input':
                    if ($i + 1 < count($argv)) {
                        $options['inputPath'] = $argv[++$i];
                    } else {
                        Logger::error('--input requires a value');
                        return null;
                    }
                    break;
                case '--output':
                    if ($i + 1 < count($argv)) {
                        $options['outputPath'] = $argv[++$i];
                    } else {
                        Logger::error('--output requires a value');
                        return null;
                    }
                    break;
                case '--server':
                    if ($i + 1 < count($argv)) {
                        $options['serverUri'] = $argv[++$i];
                    } else {
                        Logger::error('--server requires a value');
                        return null;
                    }
                    break;
                case '--verbose':
                case '-v':
                    $options['verbose'] = true;
                    break;
                case '--help':
                case '-h':
                    self::printHelp();
                    return null;
                default:
                    Logger::error('Unknown argument: ' . $argv[$i]);
                    self::printHelp();
                    return null;
            }
        }

        if ($options['inputPath'] === null) {
            Logger::error('--input is required');
            self::printHelp();
            return null;
        }

        if (!file_exists($options['inputPath'])) {
            Logger::error('Input file does not exist: ' . $options['inputPath']);
            return null;
        }

        if ($options['outputPath'] === null) {
            $timestamp = date('Ymd-His');
            $filename = basename($options['inputPath']);
            $options['outputPath'] = "audio/output/output-$timestamp-$filename";
        }

        return $options;
    }

    private static function printHelp(): void
    {
        echo <<<HELP
Audio Stream Client

Usage: php audio_stream_client.php [OPTIONS]

Options:
  --input <path>      Path to input audio file (required)
  --output <path>     Path to output audio file (optional, default: audio/output/output-<timestamp>-<filename>)
  --server <uri>      WebSocket server URI (optional, default: ws://localhost:8080/audio)
  --verbose, -v       Enable verbose logging (optional)
  --help, -h          Display this help message

Examples:
  php audio_stream_client.php --input audio/input/test.mp3
  php audio_stream_client.php --input audio/input/test.mp3 --output /tmp/output.mp3
  php audio_stream_client.php --input audio/input/test.mp3 --server ws://192.168.1.100:8080/audio --verbose

HELP;
    }
}
