import 'dart:io';
import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'types.dart';
import 'logger.dart';

/// Command-line argument parser
class CliParser {
  static Config? parse(List<String> arguments) {
    final parser = ArgParser()
      ..addOption('input', help: 'Path to input audio file (required)')
      ..addOption('output', help: 'Path to output audio file (optional)')
      ..addOption('server',
          defaultsTo: 'ws://localhost:8080/audio', help: 'WebSocket server URI')
      ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging')
      ..addFlag('help',
          abbr: 'h', help: 'Display help message', negatable: false);

    try {
      final results = parser.parse(arguments);

      if (results['help'] as bool) {
        _printHelp(parser);
        return null;
      }

      final inputPath = results['input'] as String?;
      if (inputPath == null) {
        Logger.error('--input is required');
        _printHelp(parser);
        return null;
      }

      // Validate input file
      if (!File(inputPath).existsSync()) {
        Logger.error('Input file does not exist: $inputPath');
        return null;
      }

      // Generate default output path if not provided
      String outputPath;
      if (results['output'] != null) {
        outputPath = results['output'] as String;
      } else {
        final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
        // Use platform-independent path separator
        final filename = inputPath.split(Platform.pathSeparator).last;
        outputPath =
            'audio${Platform.pathSeparator}output${Platform.pathSeparator}output-$timestamp-$filename';
      }

      final verbose = results['verbose'] as bool;
      Logger.setVerbose(verbose);

      return Config(
        inputPath: inputPath,
        outputPath: outputPath,
        serverUri: results['server'] as String,
        verbose: verbose,
      );
    } catch (e) {
      Logger.error('Error parsing arguments: $e');
      _printHelp(parser);
      return null;
    }
  }

  static void _printHelp(ArgParser parser) {
    print('''
Audio Stream Client

Usage: audio_stream_client [OPTIONS]

Options:
${parser.usage}

Examples:
  audio_stream_client --input audio/input/test.mp3
  audio_stream_client --input audio/input/test.mp3 --output /tmp/output.mp3
  audio_stream_client --input audio/input/test.mp3 --server ws://192.168.1.100:8080/audio --verbose
''');
  }
}
