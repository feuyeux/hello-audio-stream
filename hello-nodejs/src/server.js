import { Command } from 'commander';
import { run } from './server/server.js';

const program = new Command();
program
  .name('audio-stream-server')
  .option('--port <number>', 'WebSocket port', '8080')
  .option('--cache <dir>', 'Cache directory', 'cache')
  .parse(process.argv);

const opts = program.opts();
run(parseInt(opts.port, 10), opts.cache);
