#!/usr/bin/env node

/**
 * Audio Stream Cache Client - Node.js Implementation
 * Main entry point - delegates to AudioClientApplication
 */

import { AudioClientApplication } from "./client/AudioClientApplication.js";
import { parseArgs } from "./cli.js";

async function main() {
  const config = parseArgs();
  const app = new AudioClientApplication(config);
  await app.run();
}

main();
