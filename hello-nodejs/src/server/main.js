#!/usr/bin/env node

/**
 * Main entry point for Node.js audio stream server.
 * Delegates to AudioServerApplication.
 */

import { AudioServerApplication } from "./AudioServerApplication.js";

// Create and start server
const app = new AudioServerApplication(8080, "/audio");
app.start();
