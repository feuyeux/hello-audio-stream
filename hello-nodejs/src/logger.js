/**
 * Logging utility with support for different log levels
 */

let verboseEnabled = false;

export function init(verbose) {
  verboseEnabled = verbose;
}

function formatTimestamp() {
  const now = new Date();
  return now.toISOString().replace("T", " ").slice(0, 23);
}

export function info(message) {
  console.log(`[${formatTimestamp()}] [info] ${message}`);
}

export function error(message) {
  console.error(`[${formatTimestamp()}] [error] ${message}`);
}

export function warn(message) {
  console.warn(`[${formatTimestamp()}] [warn] ${message}`);
}

export function debug(message) {
  if (verboseEnabled) {
    console.log(`[${formatTimestamp()}] [debug] ${message}`);
  }
}

export function phase(message) {
  console.log();
  console.log(`[${formatTimestamp()}] [info] === ${message} ===`);
}
