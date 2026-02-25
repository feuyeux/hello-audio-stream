import { Command } from 'commander';
import { run } from './client/client.js';

const program = new Command();
program
  .name('audio-stream-client')
  .requiredOption('--input <path>', 'Input audio file path')
  .option('--server <uri>', 'WebSocket server URI', 'ws://localhost:8080')
  .option('--output <path>', 'Output file path', 'audio/output/output.opus')
  .parse(process.argv);

const opts = program.opts();
run(opts.server, opts.input, opts.output).catch(e => { console.error(e); process.exit(1); });
