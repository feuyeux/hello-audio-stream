#ifndef AUDIO_STREAM_MESSAGE_H
#define AUDIO_STREAM_MESSAGE_H

#include "protocol.h"
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace audio_stream
{

    struct Message
    {
        std::string command;
        std::string streamId;
        std::string message;
        std::string status;
        std::string streams;
        int64_t offset = -1;
        int64_t length = -1;
        int64_t size = -1;

        // ---------- parse ----------
        static Message parse(const std::string &json)
        {
            auto j = nlohmann::json::parse(json);
            Message m;
            if (j.contains("command"))
                m.command = j["command"].get<std::string>();
            if (j.contains("streamId"))
                m.streamId = j["streamId"].get<std::string>();
            if (j.contains("message"))
                m.message = j["message"].get<std::string>();
            if (j.contains("status"))
                m.status = j["status"].get<std::string>();
            if (j.contains("streams"))
                m.streams = j["streams"].get<std::string>();
            if (j.contains("offset"))
                m.offset = j["offset"].get<int64_t>();
            if (j.contains("length"))
                m.length = j["length"].get<int64_t>();
            if (j.contains("size"))
                m.size = j["size"].get<int64_t>();
            return m;
        }

        // ---------- parseCommand ----------
        std::pair<CommandInfo, Message> parseCommand() const
        {
            auto &map = commandMap();
            auto it = map.find(command);
            if (it == map.end())
            {
                throw std::runtime_error("Unknown command: " + command);
            }
            return {it->second, *this};
        }

        // ---------- serialise ----------
        std::string toJson() const
        {
            nlohmann::json j;
            if (!command.empty())
                j["command"] = command;
            if (!streamId.empty())
                j["streamId"] = streamId;
            if (!message.empty())
                j["message"] = message;
            if (!status.empty())
                j["status"] = status;
            if (!streams.empty())
                j["streams"] = streams;
            if (offset >= 0)
                j["offset"] = offset;
            if (length >= 0)
                j["length"] = length;
            if (size >= 0)
                j["size"] = size;
            return j.dump();
        }

        // ---------- factory helpers ----------
        static Message connected(const std::string &connId)
        {
            Message m;
            m.command = "CONNECTED";
            m.streamId = connId;
            return m;
        }
        static Message created(const std::string &sid)
        {
            Message m;
            m.command = "CREATED";
            m.streamId = sid;
            return m;
        }
        static Message completed(const std::string &sid)
        {
            Message m;
            m.command = "COMPLETED";
            m.streamId = sid;
            return m;
        }
        static Message closed(const std::string &sid)
        {
            Message m;
            m.command = "CLOSED";
            m.streamId = sid;
            return m;
        }
        static Message statusOf(const std::string &sid, const std::string &st, int64_t sz)
        {
            Message m;
            m.command = "STATUS";
            m.streamId = sid;
            m.status = st;
            m.size = sz;
            return m;
        }
        static Message streamList(const std::string &csv)
        {
            Message m;
            m.command = "STREAM_LIST";
            m.streams = csv;
            return m;
        }
        static Message error(const std::string &msg)
        {
            Message m;
            m.command = "ERROR";
            m.message = msg;
            return m;
        }
    };

} // namespace audio_stream

#endif // AUDIO_STREAM_MESSAGE_H
