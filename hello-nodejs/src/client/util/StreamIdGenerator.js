/**
 * Stream ID generator for creating unique stream identifiers
 * Matches the Java StreamIdGenerator interface.
 */

import crypto from "crypto";

export class StreamIdGenerator {
  static DEFAULT_PREFIX = "stream";

  /**
   * Generate a unique stream ID with default prefix "stream".
   *
   * @returns {string} stream ID in format "stream-{uuid}"
   */
  generate() {
    return this.generateWithPrefix(StreamIdGenerator.DEFAULT_PREFIX);
  }

  /**
   * Generate a unique stream ID with custom prefix.
   *
   * @param {string} prefix - prefix for the stream ID
   * @returns {string} stream ID in format "{prefix}-{uuid}"
   */
  generateWithPrefix(prefix) {
    if (!prefix) {
      prefix = StreamIdGenerator.DEFAULT_PREFIX;
    }

    const uuid = this.generateUUID();
    const streamId = `${prefix}-${uuid}`;

    return streamId;
  }

  /**
   * Generate a short stream ID (8 characters).
   *
   * @returns {string} short stream ID in format "stream-{short-uuid}"
   */
  generateShort() {
    return this.generateShortWithPrefix(StreamIdGenerator.DEFAULT_PREFIX);
  }

  /**
   * Generate a short stream ID with custom prefix.
   *
   * @param {string} prefix - prefix for the stream ID
   * @returns {string} short stream ID in format "{prefix}-{short-uuid}"
   */
  generateShortWithPrefix(prefix) {
    if (!prefix) {
      prefix = StreamIdGenerator.DEFAULT_PREFIX;
    }

    const uuid = this.generateUUID().replace(/-/g, "").substring(0, 8);
    const streamId = `${prefix}-${uuid}`;

    return streamId;
  }

  /**
   * Validate a stream ID format.
   *
   * @param {string} streamId - stream ID to validate
   * @returns {boolean} true if valid format
   */
  validate(streamId) {
    if (!streamId) {
      return false;
    }

    const pattern =
      /^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;
    return pattern.test(streamId);
  }

  /**
   * Validate a short stream ID format.
   *
   * @param {string} streamId - stream ID to validate
   * @returns {boolean} true if valid short format
   */
  validateShort(streamId) {
    if (!streamId) {
      return false;
    }

    const pattern = /^[a-zA-Z0-9_-]+-[a-f0-9]{8}$/;
    return pattern.test(streamId);
  }

  /**
   * Extract the prefix from a stream ID.
   *
   * @param {string} streamId - stream ID
   * @returns {string|null} prefix, or null if invalid format
   */
  extractPrefix(streamId) {
    if (!streamId) {
      return null;
    }

    const dashIndex = streamId.indexOf("-");
    if (dashIndex > 0) {
      return streamId.substring(0, dashIndex);
    }

    return null;
  }

  /**
   * Extract the UUID part from a stream ID.
   *
   * @param {string} streamId - stream ID
   * @returns {string|null} UUID string, or null if invalid format
   */
  extractUuid(streamId) {
    if (!streamId) {
      return null;
    }

    const dashIndex = streamId.indexOf("-");
    if (dashIndex > 0 && dashIndex < streamId.length - 1) {
      return streamId.substring(dashIndex + 1);
    }

    return null;
  }

  /**
   * Generate a UUID v4 string.
   *
   * @returns {string} UUID string
   */
  generateUUID() {
    const bytes = crypto.randomBytes(16);
    // Set version to 4 (bits 12-15 of time_hi_and_version field)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to 10 (bits 6-7 of clock_seq_hi_and_reserved field)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    const hex = bytes.toString("hex");
    return [
      hex.substr(0, 8),
      hex.substr(8, 4),
      hex.substr(12, 4),
      hex.substr(16, 4),
      hex.substr(20, 12),
    ].join("-");
  }
}
