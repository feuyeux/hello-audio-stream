<?php

declare(strict_types=1);

namespace AudioStream\Server;

enum CommandType: string
{
    case STREAM = 'STREAM';
    case DATA = 'DATA';
    case QUERY = 'QUERY';
}

enum StreamCommand: string
{
    case CREATE = 'CREATE';
    case COMPLETE = 'COMPLETE';
    case CLOSE = 'CLOSE';
}

enum DataCommand: string
{
    case READ = 'READ';
}

enum QueryCommand: string
{
    case GET_STATUS = 'GET_STATUS';
    case LIST_STREAMS = 'LIST_STREAMS';
}

final class CommandInfo
{
    public function __construct(
        public readonly CommandType $type,
        public readonly string $command,
    ) {}
}

final class Protocol
{
    /** @var array<string, CommandInfo> */
    private static array $map = [];

    public static function lookup(string $command): ?CommandInfo
    {
        if (empty(self::$map)) {
            foreach (StreamCommand::cases() as $c) {
                self::$map[$c->value] = new CommandInfo(CommandType::STREAM, $c->value);
            }
            foreach (DataCommand::cases() as $c) {
                self::$map[$c->value] = new CommandInfo(CommandType::DATA, $c->value);
            }
            foreach (QueryCommand::cases() as $c) {
                self::$map[$c->value] = new CommandInfo(CommandType::QUERY, $c->value);
            }
        }
        return self::$map[$command] ?? null;
    }
}
