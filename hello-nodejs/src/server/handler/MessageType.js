/**
 * WebSocket message types enum.
 * All type values are uppercase as per protocol specification.
 */
export class MessageType {
  static START = "START";
  static STARTED = "STARTED";
  static STOP = "STOP";
  static STOPPED = "STOPPED";
  static GET = "GET";
  static ERROR = "ERROR";
  static CONNECTED = "CONNECTED";

  /**
   * Parse string to MessageType.
   * Case-insensitive comparison for backward compatibility.
   *
   * @param {string} value - string value to parse
   * @returns {string|null} corresponding MessageType, or null if not found
   */
  static fromString(value) {
    if (!value) {
      return null;
    }
    const upperValue = value.toUpperCase();
    const validTypes = [
      this.START,
      this.STARTED,
      this.STOP,
      this.STOPPED,
      this.GET,
      this.ERROR,
      this.CONNECTED,
    ];
    return validTypes.includes(upperValue) ? upperValue : null;
  }

  /**
   * Get all valid message types.
   *
   * @returns {string[]} array of all message types
   */
  static values() {
    return [
      this.START,
      this.STARTED,
      this.STOP,
      this.STOPPED,
      this.GET,
      this.ERROR,
      this.CONNECTED,
    ];
  }
}
