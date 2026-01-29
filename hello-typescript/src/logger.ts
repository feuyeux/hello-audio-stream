/**
 * Logging utility with support for different log levels
 */

let verboseEnabled = false;

export function init(verbose: boolean): void {
  verboseEnabled = verbose;
}

function formatTimestamp(): string {
  const now = new Date();
  return now.toISOString().replace("T", " ").slice(0, 23);
}

export function info(message: string): void {
  console.log(`[${formatTimestamp()}] [info] ${message}`);
}

export function error(message: string): void {
  console.error(`[${formatTimestamp()}] [error] ${message}`);
}

export function warn(message: string): void {
  console.warn(`[${formatTimestamp()}] [warn] ${message}`);
}

export function debug(message: string): void {
  if (verboseEnabled) {
    console.log(`[${formatTimestamp()}] [debug] ${message}`);
  }
}

export function phase(message: string): void {
  console.log();
  console.log(`[${formatTimestamp()}] [info] === ${message} ===`);
}
