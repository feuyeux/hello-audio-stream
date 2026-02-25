import { Command } from 'commander';
import { run } from './client/client';

const program = new Command();
program
  .name('audio-stream-client')
  .description('Audio Stream Client - TypeScript Implementation')
  .requiredOption('--input <path>', 'Input audio file path')
  .option('--server <uri>', 'WebSocket server URI', 'ws://localhost:8080/audio')
  .option('--output <path>', 'Output file path', 'audio/output/output.opus')
  .parse(process.argv);

const opts = program.opts<{ input: string; server: string; output: string }>();
run(opts.server, opts.input, opts.output).catch((e) => {
  console.error(e);
  process.exit(1);
});
