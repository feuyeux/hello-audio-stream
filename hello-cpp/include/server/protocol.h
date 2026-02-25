#ifndef AUDIO_STREAM_PROTOCOL_H
#define AUDIO_STREAM_PROTOCOL_H

#include <string>
#include <unordered_map>

namespace audio_stream
{

    enum class CommandType
    {
        STREAM,
        DATA,
        QUERY
    };

    enum class StreamCommand
    {
        CREATE,
        COMPLETE,
        CLOSE
    };
    enum class DataCommand
    {
        READ
    };
    enum class QueryCommand
    {
        GET_STATUS,
        LIST_STREAMS
    };

    struct CommandInfo
    {
        CommandType type;
        int ordinal; // 0=STREAM, 1=DATA, 2=QUERY sub-command index
    };

    inline const std::unordered_map<std::string, CommandInfo> &commandMap()
    {
        static const std::unordered_map<std::string, CommandInfo> map = {
            {"CREATE", {CommandType::STREAM, 0}},
            {"COMPLETE", {CommandType::STREAM, 1}},
            {"CLOSE", {CommandType::STREAM, 2}},
            {"READ", {CommandType::DATA, 0}},
            {"GET_STATUS", {CommandType::QUERY, 0}},
            {"LIST_STREAMS", {CommandType::QUERY, 1}},
        };
        return map;
    }

    constexpr int DEFAULT_PORT = 8080;
    constexpr size_t CHUNK_SIZE = 65536;

} // namespace audio_stream

#endif // AUDIO_STREAM_PROTOCOL_H
