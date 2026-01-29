/**
 * CLI argument parser using commander
 */

import { Command } from "commander";
import fs from "fs";
import path from "path";

export function parseArgs() {
  const program = new Command();

  program
    .name("audio-stream-client")
    .description("Audio Stream Cache Client - Node.js Implementation")
    .version("1.0.0")
    .requiredOption("-i, --input <file>", "Input audio file path")
    .option(
      "-s, --server <uri>",
      "WebSocket server URI",
      "ws://localhost:8080/audio",
    )
    .option(
      "-o, --output <file>",
      "Output file path (auto-generated if not specified)",
    )
    .option("-v, --verbose", "Enable verbose logging", false)
    .parse();

  const options = program.opts();

  // Validate input file exists
  if (!fs.existsSync(options.input)) {
    console.error(`Error: Input file not found: ${options.input}`);
    process.exit(1);
  }

  // Generate output path if not provided
  let outputPath = options.output;
  if (!outputPath) {
    const timestamp = new Date()
      .toISOString()
      .replace(/[:.]/g, "-")
      .slice(0, 19);
    const basename = path.basename(options.input);
    outputPath = path.join(
      "audio",
      "output",
      `output-${timestamp}-${basename}`,
    );
  }

  return {
    server: options.server,
    input: options.input,
    output: outputPath,
    verbose: options.verbose,
  };
}
