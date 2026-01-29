// Stream ID generator for creating unique stream identifiers.
// Matches the Java StreamIdGenerator interface.

import 'dart:math';

/// Stream ID generator for creating unique identifiers.
class StreamIdGenerator {
  static const String _defaultPrefix = 'stream';

  /// Generate a unique stream ID with default prefix "stream".
  /// @returns stream ID in format "stream-{uuid}"
  static String generate() {
    return generateWithPrefix(_defaultPrefix);
  }

  /// Generate a unique stream ID with custom prefix.
  /// @param prefix prefix for the stream ID
  /// @returns stream ID in format "{prefix}-{uuid}"
  static String generateWithPrefix(String prefix) {
    if (prefix.isEmpty) {
      prefix = _defaultPrefix;
    }

    String uuid = _generateUUID();
    String streamId = '$prefix-$uuid';

    return streamId;
  }

  /// Generate a short stream ID (8 characters).
  /// @returns short stream ID in format "stream-{short-uuid}"
  static String generateShort() {
    return generateShortWithPrefix(_defaultPrefix);
  }

  /// Generate a short stream ID with custom prefix.
  /// @param prefix prefix for the stream ID
  /// @returns short stream ID in format "{prefix}-{short-uuid}"
  static String generateShortWithPrefix(String prefix) {
    if (prefix.isEmpty) {
      prefix = _defaultPrefix;
    }

    String uuid = _generateUUID().replaceAll('-', '').substring(0, 8);
    String streamId = '$prefix-$uuid';

    return streamId;
  }

  /// Validate a stream ID format.
  /// @param streamId stream ID to validate
  /// @returns true if valid format
  static bool validate(String streamId) {
    if (streamId.isEmpty) {
      return false;
    }

    // Check if it matches the expected pattern
    final pattern =
        RegExp(r'^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$');
    return pattern.hasMatch(streamId);
  }

  /// Validate a short stream ID format.
  /// @param streamId stream ID to validate
  /// @returns true if valid short format
  static bool validateShort(String streamId) {
    if (streamId.isEmpty) {
      return false;
    }

    // Check if it matches the short pattern: prefix-8chars
    final pattern = RegExp(r'^[a-zA-Z0-9_-]+-[a-f0-9]{8}$');
    return pattern.hasMatch(streamId);
  }

  /// Extract the prefix from a stream ID.
  /// @param streamId stream ID
  /// @returns prefix, or null if invalid format
  static String? extractPrefix(String streamId) {
    if (streamId.isEmpty) {
      return null;
    }

    int dashIndex = streamId.indexOf('-');
    if (dashIndex > 0) {
      return streamId.substring(0, dashIndex);
    }

    return null;
  }

  /// Extract the UUID part from a stream ID.
  /// @param streamId stream ID
  /// @returns UUID string, or null if invalid format
  static String? extractUuid(String streamId) {
    if (streamId.isEmpty) {
      return null;
    }

    int dashIndex = streamId.indexOf('-');
    if (dashIndex > 0 && dashIndex < streamId.length - 1) {
      return streamId.substring(dashIndex + 1);
    }

    return null;
  }

  /// Generate a UUID v4 string.
  /// @returns UUID string
  static String _generateUUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));

    // Set version to 4 (bits 12-15 of time_hi_and_version field)
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Set variant to 10 (bits 6-7 of clock_seq_hi_and_reserved field)
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    // Convert to hex string and format as UUID
    String hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20, 32)
    ].join('-');
  }
}
