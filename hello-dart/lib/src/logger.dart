import 'package:intl/intl.dart';

/// Simple logging utility
class Logger {
  static final _formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  static bool _verboseEnabled = false;

  static void setVerbose(bool enabled) {
    _verboseEnabled = enabled;
  }

  static void debug(String message) {
    if (_verboseEnabled) {
      _log('debug', message);
    }
  }

  static void info(String message) {
    _log('info', message);
  }

  static void warn(String message) {
    _log('warn', message);
  }

  static void error(String message) {
    _log('error', message);
  }

  static void _log(String level, String message) {
    final timestamp = _formatter.format(DateTime.now());
    print('[$timestamp] [$level] $message');
  }
}
