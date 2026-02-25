import { Command } from 'commander';
import { run } from './server/server';

const program = new Command();
program
  .name('audio-stream-server')
  .description('Audio Stream Server - TypeScript Implementation')
  .option('--port <number>', 'WebSocket port', '8080')
  .option('--cache <dir>', 'Cache directory', 'cache')
  .parse(process.argv);

const opts = program.opts<{ port: string; cache: string }>();
run(parseInt(opts.port, 10), opts.cache);
